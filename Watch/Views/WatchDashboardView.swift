import SwiftUI

// MARK: - Watch Dashboard

struct WatchDashboardView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @State private var recovery: RecoveryData?
    @State private var exertion: ExertionData?
    @State private var energy: EnergyData?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 30)
                    } else {
                        // Recovery
                        WatchRecoveryCard(recovery: recovery)

                        // Exertion
                        WatchExertionCard(exertion: exertion)

                        // Energy
                        WatchEnergyCard(energy: energy)
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("HealthPulse")
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true

        do {
            let baseline = try await healthKit.buildBaseline()

            // Recovery
            if let hrv = try await healthKit.fetchLatestHRV(),
               let rhr = try await healthKit.fetchLatestRHR() {
                recovery = RecoveryCalculator.calculate(
                    todayHRV: hrv, todayRHR: rhr, baseline: baseline
                )
            }

            // Exertion
            let today = Calendar.current.startOfDay(for: Date())
            let hrSamples = try await healthKit.fetchHeartRateSamples(from: today, to: Date())
            exertion = ExertionCalculator.calculate(hrSamples: hrSamples, baseline: baseline)

            // Energy
            let active = try await healthKit.fetchActiveEnergy(for: Date())
            let basal = try await healthKit.fetchBasalEnergy(for: Date())
            energy = EnergyData(date: Date(), activeCalories: active, basalCalories: basal)
        } catch {
            print("Watch data load error: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Watch Recovery Card

struct WatchRecoveryCard: View {
    let recovery: RecoveryData?

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                Text("Recovery")
                    .font(.caption2.bold())
                Spacer()
            }

            if let recovery = recovery {
                HStack {
                    Text("\(Int(recovery.score))%")
                        .font(.title2.bold())
                        .foregroundStyle(colorForLevel(recovery.level))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("HRV \(Int(recovery.hrvValue))ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("RHR \(Int(recovery.rhrValue))bpm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(recovery.level.localizedName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorForLevel(_ level: RecoveryLevel) -> Color {
        switch level {
        case .green:  return .green
        case .yellow: return .yellow
        case .red:    return .red
        }
    }
}

// MARK: - Watch Exertion Card

struct WatchExertionCard: View {
    let exertion: ExertionData?

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.caption2)
                Text("Exertion")
                    .font(.caption2.bold())
                Spacer()
            }

            if let exertion = exertion {
                HStack {
                    Text(String(format: "%.1f", exertion.score))
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                    Text("/ 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(exertion.level.localizedName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let target = exertion.targetZone {
                    Text("Target: \(target.range)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Watch Energy Card

struct WatchEnergyCard: View {
    let energy: EnergyData?

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption2)
                Text("Energy")
                    .font(.caption2.bold())
                Spacer()
            }

            if let energy = energy {
                HStack {
                    Text(String(format: "%.0f", energy.totalCalories))
                        .font(.title2.bold())
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    HStack(spacing: 2) {
                        Circle().fill(.red).frame(width: 5, height: 5)
                        Text(String(format: "%.0f", energy.activeCalories))
                            .font(.caption2)
                    }
                    HStack(spacing: 2) {
                        Circle().fill(.blue.opacity(0.5)).frame(width: 5, height: 5)
                        Text(String(format: "%.0f", energy.basalCalories))
                            .font(.caption2)
                    }
                    Spacer()
                }
                .foregroundStyle(.secondary)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
