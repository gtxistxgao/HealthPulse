import SwiftUI
import Charts

// MARK: - Main Dashboard

struct DashboardView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading health data...")
                        .padding(.top, 100)
                } else {
                    VStack(spacing: 16) {
                        // Top cards: Recovery + Sleep
                        HStack(spacing: 12) {
                            RecoveryCardView(recovery: viewModel.recovery)
                            SleepCardView(sleep: viewModel.sleep)
                        }
                        .padding(.horizontal)

                        // Bottom cards: Exertion + Energy
                        HStack(spacing: 12) {
                            ExertionCardView(exertion: viewModel.exertion)
                            EnergyCardView(energy: viewModel.energy)
                        }
                        .padding(.horizontal)

                        // Health Metrics Summary
                        if let metrics = viewModel.healthMetrics {
                            HealthMetricsSummary(metrics: metrics)
                                .padding(.horizontal)
                        }

                        // Baseline info
                        if let baseline = viewModel.baseline {
                            BaselineInfoView(baseline: baseline)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("HealthPulse")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if viewModel.recovery == nil {
                    // Re-create VM with correct HealthKit instance
                    let vm = DashboardViewModel(healthKit: healthKit)
                    await vm.loadAllData()
                }
            }
        }
    }
}

// MARK: - Recovery Card

struct RecoveryCardView: View {
    let recovery: RecoveryData?

    var body: some View {
        VStack(spacing: 10) {
            Text("Recovery")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let recovery = recovery {
                ScoreBadge(
                    score: recovery.score,
                    label: recovery.level.localizedName,
                    color: colorForRecovery(recovery.level),
                    size: 80
                )

                VStack(spacing: 2) {
                    HStack {
                        Text("HRV")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f ms", recovery.hrvValue))
                            .font(.caption2.bold())
                    }
                    HStack {
                        Text("RHR")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f bpm", recovery.rhrValue))
                            .font(.caption2.bold())
                    }
                }
            } else {
                EmptyStateView(icon: "heart.slash", title: "No Data", message: "Wear your Apple Watch to sleep")
                    .frame(height: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func colorForRecovery(_ level: RecoveryLevel) -> Color {
        switch level {
        case .green:  return .green
        case .yellow: return .yellow
        case .red:    return .red
        }
    }
}

// MARK: - Sleep Card

struct SleepCardView: View {
    let sleep: SleepData?

    var body: some View {
        VStack(spacing: 10) {
            Text("Sleep")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let sleep = sleep {
                ScoreBadge(
                    score: sleep.score,
                    label: sleep.level.localizedName,
                    color: colorForSleep(sleep.level),
                    size: 80
                )

                VStack(spacing: 2) {
                    HStack {
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatHours(sleep.totalSleepHours))
                            .font(.caption2.bold())
                    }
                    HStack {
                        Text("Efficiency")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", sleep.sleepEfficiency * 100))
                            .font(.caption2.bold())
                    }
                }
            } else {
                EmptyStateView(icon: "moon.zzz", title: "No Data", message: "Sleep data from Apple Watch needed")
                    .frame(height: 80)
            }
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

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
}

// MARK: - Exertion Card

struct ExertionCardView: View {
    let exertion: ExertionData?

    var body: some View {
        VStack(spacing: 10) {
            Text("Exertion")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let exertion = exertion {
                ScoreBadge(
                    score: exertion.score,
                    maxScore: 10,
                    label: exertion.level.localizedName,
                    color: .orange,
                    size: 80
                )

                if let target = exertion.targetZone {
                    HStack {
                        Text("Target")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(target.range)
                            .font(.caption2.bold())
                    }
                }
            } else {
                EmptyStateView(icon: "flame.slash", title: "No Data", message: "Heart rate data needed")
                    .frame(height: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Energy Card

struct EnergyCardView: View {
    let energy: EnergyData?

    var body: some View {
        VStack(spacing: 10) {
            Text("Energy")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let energy = energy {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", energy.totalCalories))
                        .font(.title.bold())
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 80)

                VStack(spacing: 2) {
                    HStack {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("Active")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f", energy.activeCalories))
                            .font(.caption2.bold())
                    }
                    HStack {
                        Circle().fill(.blue.opacity(0.5)).frame(width: 6, height: 6)
                        Text("Basal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f", energy.basalCalories))
                            .font(.caption2.bold())
                    }
                }
            } else {
                EmptyStateView(icon: "bolt.slash", title: "No Data", message: "Energy data loading...")
                    .frame(height: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Health Metrics Summary

struct HealthMetricsSummary: View {
    let metrics: HealthMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Health Metrics", icon: "waveform.path.ecg")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                if let hrv = metrics.hrv {
                    MetricRow(name: "HRV", value: String(format: "%.0f", hrv.value), unit: hrv.unit, status: hrv.status)
                }
                if let rhr = metrics.restingHR {
                    MetricRow(name: "RHR", value: String(format: "%.0f", rhr.value), unit: rhr.unit, status: rhr.status)
                }
                if let spo2 = metrics.bloodOxygen {
                    MetricRow(name: "SpO2", value: String(format: "%.0f", spo2.value), unit: spo2.unit, status: spo2.status)
                }
                if let resp = metrics.respiratoryRate {
                    MetricRow(name: "Resp", value: String(format: "%.1f", resp.value), unit: resp.unit, status: resp.status)
                }
            }
        }
    }
}

struct MetricRow: View {
    let name: String
    let value: String
    let unit: String
    let status: MetricStatus

    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .font(.caption)
                .foregroundStyle(colorForStatus(status))

            VStack(alignment: .leading) {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(value) \(unit)")
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func colorForStatus(_ status: MetricStatus) -> Color {
        switch status {
        case .normal:   return .green
        case .elevated: return .orange
        case .abnormal: return .red
        }
    }
}

// MARK: - Baseline Info

struct BaselineInfoView: View {
    let baseline: HealthBaseline

    var body: some View {
        if !baseline.isReady {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Building your personal baseline... \(baseline.sampleDays)/7 days of data collected. Scores will become more accurate over time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
