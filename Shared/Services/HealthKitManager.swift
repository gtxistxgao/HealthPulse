import Foundation
import HealthKit

// MARK: - HealthKit Data Access Layer

@MainActor
final class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationError: String?

    // All HealthKit types we need to read
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate),
            HKCategoryType(.sleepAnalysis),
        ]
        // Wrist temperature only available on watchOS 9+ / iOS 16+
        if #available(iOS 16.0, watchOS 9.0, *) {
            types.insert(HKQuantityType(.appleSleepingWristTemperature))
        }
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "Health data is not available on this device."
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            authorizationError = "Failed to authorize HealthKit: \(error.localizedDescription)"
        }
    }

    // MARK: - HRV Queries

    /// Fetch the most recent HRV reading (typically from last night's sleep)
    func fetchLatestHRV() async throws -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let sample = try await fetchMostRecentSample(type: type)
        return sample?.quantity.doubleValue(for: .secondUnit(with: .milli))
    }

    /// Fetch HRV values over a date range
    func fetchHRVHistory(days: Int) async throws -> [(date: Date, value: Double)] {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let samples = try await fetchSamples(type: type, from: start, to: Date())
        return samples.map { (
            date: $0.endDate,
            value: $0.quantity.doubleValue(for: .secondUnit(with: .milli))
        )}
    }

    // MARK: - Resting Heart Rate

    func fetchLatestRHR() async throws -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let sample = try await fetchMostRecentSample(type: type)
        return sample?.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
    }

    func fetchRHRHistory(days: Int) async throws -> [(date: Date, value: Double)] {
        let type = HKQuantityType(.restingHeartRate)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let samples = try await fetchSamples(type: type, from: start, to: Date())
        return samples.map { (
            date: $0.endDate,
            value: $0.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        )}
    }

    // MARK: - Heart Rate (for Exertion)

    func fetchHeartRateSamples(from start: Date, to end: Date) async throws -> [(date: Date, bpm: Double)] {
        let type = HKQuantityType(.heartRate)
        let samples = try await fetchSamples(type: type, from: start, to: end)
        return samples.map { (
            date: $0.startDate,
            bpm: $0.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        )}
    }

    /// Get the maximum heart rate recorded in last N days
    func fetchMaxHeartRate(days: Int) async throws -> Double? {
        let type = HKQuantityType(.heartRate)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .init(type: type, predicate: predicate),
            options: .discreteMax
        )

        let result = try await descriptor.result(for: healthStore)
        return result?.maximumQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
    }

    // MARK: - Sleep Analysis

    func fetchSleepSamples(from start: Date, to end: Date) async throws -> [HKCategorySample] {
        let type = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch last night's sleep (from 6pm yesterday to noon today)
    func fetchLastNightSleep() async throws -> [HKCategorySample] {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
        let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        return try await fetchSleepSamples(from: start, to: end)
    }

    // MARK: - Energy Burned

    func fetchActiveEnergy(for date: Date) async throws -> Double {
        let type = HKQuantityType(.activeEnergyBurned)
        return try await fetchDailySum(type: type, date: date)
    }

    func fetchBasalEnergy(for date: Date) async throws -> Double {
        let type = HKQuantityType(.basalEnergyBurned)
        return try await fetchDailySum(type: type, date: date)
    }

    // MARK: - Health Metrics

    func fetchLatestBloodOxygen() async throws -> Double? {
        let type = HKQuantityType(.oxygenSaturation)
        let sample = try await fetchMostRecentSample(type: type)
        return sample.map { $0.quantity.doubleValue(for: .percent()) * 100 }
    }

    func fetchLatestRespiratoryRate() async throws -> Double? {
        let type = HKQuantityType(.respiratoryRate)
        let sample = try await fetchMostRecentSample(type: type)
        return sample?.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
    }

    @available(iOS 16.0, watchOS 9.0, *)
    func fetchLatestWristTemperature() async throws -> Double? {
        let type = HKQuantityType(.appleSleepingWristTemperature)
        let sample = try await fetchMostRecentSample(type: type)
        return sample?.quantity.doubleValue(for: .degreeCelsius())
    }

    // MARK: - Baseline Calculations

    /// Build a 60-day baseline for Recovery calculations
    func buildBaseline() async throws -> HealthBaseline {
        var baseline = HealthBaseline()

        // HRV baseline (60 days)
        let hrvHistory = try await fetchHRVHistory(days: 60)
        if !hrvHistory.isEmpty {
            let values = hrvHistory.map(\.value)
            baseline.avgHRV = values.mean
            baseline.stdHRV = values.standardDeviation
        }

        // RHR baseline (60 days)
        let rhrHistory = try await fetchRHRHistory(days: 60)
        if !rhrHistory.isEmpty {
            let values = rhrHistory.map(\.value)
            baseline.avgRHR = values.mean
            baseline.stdRHR = values.standardDeviation
        }

        // Max HR (30 days)
        if let maxHR = try await fetchMaxHeartRate(days: 30) {
            baseline.maxHR = maxHR
        }

        baseline.sampleDays = min(hrvHistory.count, rhrHistory.count)
        return baseline
    }

    /// Build metric-specific baseline
    func buildMetricBaseline(type: HKQuantityType, unit: HKUnit, days: Int = 60) async throws -> MetricBaseline? {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let samples = try await fetchSamples(type: type, from: start, to: Date())
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        guard values.count >= 7 else { return nil }
        return MetricBaseline(mean: values.mean, stdDev: values.standardDeviation, sampleCount: values.count)
    }

    // MARK: - Private Helpers

    private func fetchMostRecentSample(type: HKQuantityType) async throws -> HKQuantitySample? {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            end: Date()
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSamples(type: HKQuantityType, from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: quantitySamples)
            }
            healthStore.execute(query)
        }
    }

    private func fetchDailySum(type: HKQuantityType, date: Date) async throws -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .init(type: type, predicate: predicate),
            options: .cumulativeSum
        )

        let result = try await descriptor.result(for: healthStore)
        return result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }
}
