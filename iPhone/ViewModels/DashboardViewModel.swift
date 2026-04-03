import Foundation
import SwiftUI

// MARK: - Main Dashboard ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    private let healthKit: HealthKitManager

    @Published var recovery: RecoveryData?
    @Published var sleep: SleepData?
    @Published var exertion: ExertionData?
    @Published var energy: EnergyData?
    @Published var healthMetrics: HealthMetrics?
    @Published var baseline: HealthBaseline?
    @Published var trainingGoal: TrainingGoal = .maintain

    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var sleepStages: [SleepStage] = []

    init(healthKit: HealthKitManager) {
        self.healthKit = healthKit
    }

    /// Load all data for today's dashboard
    func loadAllData() async {
        isLoading = true
        errorMessage = nil

        // Step 1: Build baseline (needed for Recovery and Exertion)
        do {
            baseline = try await healthKit.buildBaseline()
        } catch {
            errorMessage = "Failed to build baseline: \(error.localizedDescription)"
        }

        // Step 2: Load all modules concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRecovery() }
            group.addTask { await self.loadSleep() }
            group.addTask { await self.loadExertion() }
            group.addTask { await self.loadEnergy() }
            group.addTask { await self.loadHealthMetrics() }
        }

        // Step 3: Calculate target exertion based on recovery
        if let recoveryScore = recovery?.score {
            let target = RecoveryCalculator.targetExertion(
                recoveryScore: recoveryScore,
                goal: trainingGoal
            )
            // Update exertion with target zone
            if let currentExertion = exertion {
                exertion = ExertionData(
                    date: currentExertion.date,
                    score: currentExertion.score,
                    rawTRIMP: currentExertion.rawTRIMP,
                    zoneDurations: currentExertion.zoneDurations,
                    targetZone: target
                )
            }
        }

        isLoading = false
    }

    // MARK: - Individual Loaders

    private func loadRecovery() async {
        guard let baseline = baseline else { return }
        do {
            let hrv = try await healthKit.fetchLatestHRV()
            let rhr = try await healthKit.fetchLatestRHR()
            guard let hrvValue = hrv, let rhrValue = rhr else { return }

            recovery = RecoveryCalculator.calculate(
                todayHRV: hrvValue,
                todayRHR: rhrValue,
                baseline: baseline
            )
        } catch {
            print("Recovery load error: \(error)")
        }
    }

    private func loadSleep() async {
        do {
            let samples = try await healthKit.fetchLastNightSleep()
            sleep = SleepAnalyzer.analyze(samples: samples)
            sleepStages = SleepAnalyzer.extractStages(from: samples)
        } catch {
            print("Sleep load error: \(error)")
        }
    }

    private func loadExertion() async {
        guard let baseline = baseline else { return }
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let hrSamples = try await healthKit.fetchHeartRateSamples(from: today, to: Date())
            exertion = ExertionCalculator.calculate(
                hrSamples: hrSamples,
                baseline: baseline
            )
        } catch {
            print("Exertion load error: \(error)")
        }
    }

    private func loadEnergy() async {
        do {
            let active = try await healthKit.fetchActiveEnergy(for: Date())
            let basal = try await healthKit.fetchBasalEnergy(for: Date())
            energy = EnergyData(date: Date(), activeCalories: active, basalCalories: basal)
        } catch {
            print("Energy load error: \(error)")
        }
    }

    private func loadHealthMetrics() async {
        healthMetrics = await HealthMonitor.buildMetrics(using: healthKit)
    }

    /// Refresh data
    func refresh() async {
        await loadAllData()
    }
}
