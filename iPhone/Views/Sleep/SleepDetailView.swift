import SwiftUI
import Charts

// MARK: - Sleep Detail View

struct SleepDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let sleep = viewModel.sleep {
                        // Score overview
                        SleepScoreHeader(sleep: sleep)

                        // Sleep stages timeline
                        if !viewModel.sleepStages.isEmpty {
                            SleepStagesChart(stages: viewModel.sleepStages)
                        }

                        // Stage breakdown
                        SleepStageBreakdown(sleep: sleep)

                        // Detail metrics
                        SleepMetricsGrid(sleep: sleep)

                    } else {
                        EmptyStateView(
                            icon: "moon.zzz",
                            title: "No Sleep Data",
                            message: "Wear your Apple Watch to sleep tonight to see your sleep analysis."
                        )
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep")
        }
    }
}

// MARK: - Sleep Score Header

struct SleepScoreHeader: View {
    let sleep: SleepData

    var body: some View {
        VStack(spacing: 12) {
            ScoreBadge(
                score: sleep.score,
                label: sleep.level.localizedName,
                color: colorForSleep(sleep.level),
                size: 120
            )

            Text(String(format: "%dh %dm total sleep",
                         Int(sleep.totalSleepHours),
                         Int((sleep.totalSleepHours - floor(sleep.totalSleepHours)) * 60)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func colorForSleep(_ level: SleepLevel) -> Color {
        switch level {
        case .excellent: return .blue
        case .good:      return .cyan
        case .fair:      return .orange
        case .poor:      return .red
        }
    }
}

// MARK: - Sleep Stages Timeline Chart

struct SleepStagesChart: View {
    let stages: [SleepStage]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Sleep Stages", icon: "chart.bar.fill")

            Chart {
                ForEach(stages) { stage in
                    RectangleMark(
                        xStart: .value("Start", stage.startDate),
                        xEnd: .value("End", stage.endDate),
                        y: .value("Stage", stage.stage.localizedName)
                    )
                    .foregroundStyle(colorForStage(stage.stage))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 1)) {
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                }
            }
            .frame(height: 150)

            // Legend
            HStack(spacing: 16) {
                ForEach(SleepStageType.allCases, id: \.rawValue) { stage in
                    HStack(spacing: 4) {
                        Circle().fill(colorForStage(stage)).frame(width: 8, height: 8)
                        Text(stage.localizedName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func colorForStage(_ stage: SleepStageType) -> Color {
        switch stage {
        case .awake: return .red.opacity(0.7)
        case .rem:   return .cyan
        case .core:  return .blue.opacity(0.6)
        case .deep:  return .indigo
        }
    }
}

// MARK: - Stage Breakdown (pie/bar style)

struct SleepStageBreakdown: View {
    let sleep: SleepData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Stage Breakdown", icon: "chart.pie.fill")

            VStack(spacing: 8) {
                StageBar(name: "Deep", minutes: sleep.deepMinutes,
                         percentage: sleep.deepPercentage, color: .indigo,
                         idealRange: "15-25%")
                StageBar(name: "REM", minutes: sleep.remMinutes,
                         percentage: sleep.remPercentage, color: .cyan,
                         idealRange: "20-25%")
                StageBar(name: "Core", minutes: sleep.coreMinutes,
                         percentage: sleep.corePercentage, color: .blue.opacity(0.6),
                         idealRange: "45-55%")
                StageBar(name: "Awake", minutes: sleep.awakeMinutes,
                         percentage: sleep.totalSleepMinutes > 0
                            ? sleep.awakeMinutes / (sleep.totalSleepMinutes + sleep.awakeMinutes) * 100
                            : 0,
                         color: .red.opacity(0.5),
                         idealRange: "<5%")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StageBar: View {
    let name: String
    let minutes: Double
    let percentage: Double
    let color: Color
    let idealRange: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline.bold())
                Spacer()
                Text(String(format: "%dm (%.0f%%)", Int(minutes), percentage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(percentage / 100, 1.0), height: 8)
                }
            }
            .frame(height: 8)

            Text("Ideal: \(idealRange)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Sleep Metrics Grid

struct SleepMetricsGrid: View {
    let sleep: SleepData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Details", icon: "list.bullet")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricCardView(
                    title: "Sleep Efficiency",
                    value: String(format: "%.0f%%", sleep.sleepEfficiency * 100),
                    subtitle: "Time asleep / in bed",
                    icon: "percent",
                    color: .blue
                )
                MetricCardView(
                    title: "Interruptions",
                    value: "\(sleep.interruptions)",
                    subtitle: "Times woken up",
                    icon: "exclamationmark.triangle",
                    color: sleep.interruptions > 3 ? .red : .green
                )
                MetricCardView(
                    title: "Time in Bed",
                    value: String(format: "%.1fh", sleep.inBedHours),
                    subtitle: "Total in-bed time",
                    icon: "bed.double",
                    color: .purple
                )

                if let dip = sleep.heartRateDip {
                    MetricCardView(
                        title: "HR Dip",
                        value: String(format: "%.0f%%", dip),
                        subtitle: dip > 10 ? "Healthy dip" : "Low dip",
                        icon: "heart.fill",
                        color: dip > 10 ? .green : .orange
                    )
                }
            }
        }
    }
}
