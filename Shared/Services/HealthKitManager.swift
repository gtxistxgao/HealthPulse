import Foundation
import HealthKit

/// Wraps `HKHealthStore` to provide authorization and read access to the
/// physiological metrics HealthPulse cares about.
///
/// All reads are exposed as `async`/`await` methods. Latest-value and history
/// reads are built on the classic, broadly-available query classes bridged to
/// concurrency with `withCheckedContinuation`; the per-day energy sums use the
/// modern `HKStatisticsQueryDescriptor`. Failures are treated as "no data":
/// latest reads return `nil`, history reads return an empty array and energy
/// sums return `0`, so callers never have to handle thrown errors for the
/// common "metric simply isn't present" case.
@MainActor
final class HealthKitManager: ObservableObject {
    /// Whether `requestAuthorization()` has completed without throwing.
    ///
    /// HealthKit deliberately never reveals *read* permission status (to avoid
    /// leaking that a value is absent because the user denied access), so this
    /// only reflects that the authorization request itself succeeded.
    @Published private(set) var isAuthorized = false

    private let healthStore = HKHealthStore()

    init() {}

    // MARK: - Sample types

    /// Heart-rate variability, measured as SDNN, in milliseconds.
    private static let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    /// Instantaneous heart rate, in beats per minute.
    private static let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    /// Resting heart rate, in beats per minute.
    private static let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
    /// Active energy burned, in kilocalories.
    private static let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    /// Basal (resting) energy burned, in kilocalories.
    private static let basalEnergyType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
    /// Blood oxygen saturation, as a fraction (`0...1`).
    private static let oxygenSaturationType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!
    /// Respiratory rate, in breaths per minute.
    private static let respiratoryRateType = HKObjectType.quantityType(forIdentifier: .respiratoryRate)!

    /// Every quantity type the app requests read access to.
    private static let readTypes: Set<HKObjectType> = [
        hrvType,
        heartRateType,
        restingHeartRateType,
        activeEnergyType,
        basalEnergyType,
        oxygenSaturationType,
        respiratoryRateType,
    ]

    // MARK: - Units

    private static let countPerMinute = HKUnit.count().unitDivided(by: .minute())
    private static let millisecond = HKUnit.secondUnit(with: .milli)
    private static let kilocalorie = HKUnit.kilocalorie()
    private static let percent = HKUnit.percent()

    // MARK: - Authorization

    /// Request read authorization for all the health data types the app needs.
    ///
    /// The app never writes health data, so the share set is empty. On success
    /// ``isAuthorized`` is set to `true`; if HealthKit is unavailable on the
    /// device or the request throws, it is set to `false`.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }
        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: Self.readTypes
            )
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Latest single values

    /// The most recent HRV (SDNN) reading, in milliseconds, or `nil`.
    func fetchLatestHRV() async -> Double? {
        await fetchLatestQuantity(Self.hrvType, unit: Self.millisecond)
    }

    /// The most recent resting heart rate, in bpm, or `nil`.
    func fetchLatestRHR() async -> Double? {
        await fetchLatestQuantity(Self.restingHeartRateType, unit: Self.countPerMinute)
    }

    /// The most recent blood oxygen saturation, as a percentage (`0...100`),
    /// or `nil`. HealthKit stores this as a fraction; it is scaled to a percent
    /// here for display convenience.
    func fetchLatestBloodOxygen() async -> Double? {
        guard let fraction = await fetchLatestQuantity(
            Self.oxygenSaturationType,
            unit: Self.percent
        ) else {
            return nil
        }
        // `HKUnit.percent()` yields the raw fraction (e.g. 0.98); present it as
        // a 0...100 percentage.
        return fraction * 100
    }

    /// The most recent respiratory rate, in breaths per minute, or `nil`.
    func fetchLatestRespiratoryRate() async -> Double? {
        await fetchLatestQuantity(Self.respiratoryRateType, unit: Self.countPerMinute)
    }

    // MARK: - History

    /// Daily-average HRV (SDNN) values, in milliseconds, for the last `days`
    /// days. Days with no samples are omitted.
    func fetchHRVHistory(days: Int) async -> [Double] {
        await fetchDailyAverages(Self.hrvType, unit: Self.millisecond, days: days)
    }

    /// Daily-average resting heart rate, in bpm, for the last `days` days.
    /// Days with no samples are omitted.
    func fetchRHRHistory(days: Int) async -> [Double] {
        await fetchDailyAverages(
            Self.restingHeartRateType,
            unit: Self.countPerMinute,
            days: days
        )
    }

    // MARK: - Energy

    /// Total active energy burned, in kilocalories, on the calendar day
    /// containing `date`. Returns `0` when there is no data.
    func fetchActiveEnergy(for date: Date) async -> Double {
        await fetchEnergySum(Self.activeEnergyType, for: date)
    }

    /// Total basal energy burned, in kilocalories, on the calendar day
    /// containing `date`. Returns `0` when there is no data.
    func fetchBasalEnergy(for date: Date) async -> Double {
        await fetchEnergySum(Self.basalEnergyType, for: date)
    }

    // MARK: - Query helpers

    /// Reads the single most recent sample of `type` and converts it to `unit`.
    private func fetchLatestQuantity(
        _ type: HKQuantityType,
        unit: HKUnit
    ) async -> Double? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let sort = NSSortDescriptor(
                key: HKSampleSortIdentifierEndDate,
                ascending: false
            )
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity
                    .doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Sums a cumulative quantity (energy) over the calendar day containing
    /// `date` using a `HKStatisticsQueryDescriptor`.
    private func fetchEnergySum(_ type: HKQuantityType, for date: Date) async -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return 0
        }
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(
                type: type,
                predicate: HKQuery.predicateForSamples(withStart: start, end: end)
            ),
            options: .cumulativeSum
        )
        do {
            let statistics = try await descriptor.result(for: healthStore)
            return statistics?.sumQuantity()?.doubleValue(for: Self.kilocalorie) ?? 0
        } catch {
            return 0
        }
    }

    /// Computes per-day average values of `type` over the last `days` days via a
    /// `HKStatisticsCollectionQuery` bucketed into one-day intervals. Days
    /// without samples produce no entry.
    private func fetchDailyAverages(
        _ type: HKQuantityType,
        unit: HKUnit,
        days: Int
    ) async -> [Double] {
        guard days > 0 else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let anchor = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -days, to: anchor) else {
            return []
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<[Double], Never>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: now),
                options: .discreteAverage,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, _ in
                var values: [Double] = []
                collection?.enumerateStatistics(from: start, to: now) { statistics, _ in
                    if let average = statistics.averageQuantity()?.doubleValue(for: unit) {
                        values.append(average)
                    }
                }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }
}
