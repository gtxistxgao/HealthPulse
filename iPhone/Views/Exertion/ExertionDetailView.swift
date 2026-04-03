import SwiftUI
import Charts

// MARK: - Exertion Detail View

struct ExertionDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let exertion = viewModel.exertion {
                        // Score + Target
                        ExertionScoreHeader(exertion: exertion)

                        // Heart Rate Zone Breakdown
                        HRZoneChart(zoneDurations: exertion.zoneDurations)

                        // Zone Details
                        if let baseline = viewModel.baseline {
                            HRZoneDetails(baseline: baseline, zoneDurations: exertion.zoneDurations)
                        }

                        // Training Goal Selector
                        TrainingGoalSelector(
                            selectedGoal: $viewModel.trainingGoal,
                            recovery: viewModel.recovery
                        )

                    } else {
                        EmptyStateView(
                            icon: "flame",
                            title: "No Exertion Data",
                            message: "Heart rate data will be used to calculate your daily exertion score."
                        )
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .navigationTitle("Exertion")
        }
    }
}

// MARK: - Exertion Score Header

struct ExertionScoreHeader: View {
    let exertion: ExertionData

    var body: some View {
        VStack(spacing: 12) {
            // Score ring
            ZStack {
                CircularProgressView(
                    progress: exertion.score / 10,
                    lineWidth: 12,
                    color: .orange,
                    size: 120
                )

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", exertion.score))
                        .font(.largeTitle.bold())
                    Text("/ 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(exertion.level.localizedName)
                .font(.headline)
                .foregroundStyle(.orange)

            // Target zone
            if let target = exertion.targetZone {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.blue)
                    Text("Target: \(target.range)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.1))
                .clipShape(Capsule())

                // Status indicator
                let inTarget = exertion.score >= target.minScore && exertion.score <= target.maxScore
                let belowTarget = exertion.score < target.minScore
                Text(inTarget ? "In target zone" :
                        belowTarget ? "Below target — more activity recommended" :
                        "Above target — consider rest")
                    .font(.caption)
                    .foregroundStyle(inTarget ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Heart Rate Zone Chart

struct HRZoneChart: View {
    let zoneDurations: [HeartRateZoneDuration]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Heart Rate Zones", icon: "heart.fill")

            Chart {
                ForEach(zoneDurations) { zd in
                    BarMark(
                        x: .value("Duration", zd.durationMinutes),
                        y: .value("Zone", zd.zone.name)
                    )
                    .foregroundStyle(colorForZone(zd.zone))
                    .annotation(position: .trailing, alignment: .leading) {
                        if zd.durationMinutes > 0 {
                            Text(String(format: "%.0fm", zd.durationMinutes))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxisLabel("Minutes")
            .frame(height: 200)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func colorForZone(_ zone: HeartRateZone) -> Color {
        switch zone {
        case .zone1: return .gray
        case .zone2: return .blue
        case .zone3: return .green
        case .zone4: return .orange
        case .zone5: return .red
        }
    }
}

// MARK: - Zone Details with HR Ranges

struct HRZoneDetails: View {
    let baseline: HealthBaseline
    let zoneDurations: [HeartRateZoneDuration]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Your Heart Rate Zones", icon: "waveform.path.ecg")

            let zoneRanges = ExertionCalculator.zoneHeartRates(baseline: baseline)

            ForEach(zoneRanges, id: \.zone) { item in
                let duration = zoneDurations.first(where: { $0.zone == item.zone })?.durationMinutes ?? 0

                HStack {
                    Text(item.zone.name)
                        .font(.subheadline.bold())
                        .frame(width: 50, alignment: .leading)

                    Text("\(item.minBPM)-\(item.maxBPM) bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Text(item.zone.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: "%.0fm", duration))
                        .font(.subheadline.bold())
                }
                .padding(.vertical, 4)

                if item.zone != .zone5 {
                    Divider()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Training Goal Selector

struct TrainingGoalSelector: View {
    @Binding var selectedGoal: TrainingGoal
    let recovery: RecoveryData?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Training Goal", icon: "figure.run")

            Picker("Goal", selection: $selectedGoal) {
                ForEach(TrainingGoal.allCases) { goal in
                    Text(goal.localizedName).tag(goal)
                }
            }
            .pickerStyle(.segmented)

            if let recovery = recovery {
                let target = RecoveryCalculator.targetExertion(
                    recoveryScore: recovery.score,
                    goal: selectedGoal
                )
                Text("Based on your Recovery (\(Int(recovery.score))%), your target exertion today is \(target.range)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
