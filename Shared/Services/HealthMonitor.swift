import Foundation
import HealthKit

// MARK: - Health Metrics Monitor

/// Monitors key health metrics and detects anomalies by comparing
/// current readings against personal 60-day baselines.
struct HealthMonitor {

    /// Build today's health metrics snapshot with anomaly detection
    static func buildMetrics(using manager: HealthKitManager) async -> HealthMetrics {
        async let hrvReading = buildReading(
            fetcher: { try await manager.fetchLatestHRV() },
            baselineBuilder: {
                try await manager.buildMetricBaseline(
                    type: HKQuantityType(.heartRateVariabilitySDNN),
                    unit: .secondUnit(with: .milli)
                )
            },
            unit: "ms"
        )

        async let rhrReading = buildReading(
            fetcher: { try await manager.fetchLatestRHR() },
            baselineBuilder: {
                try await manager.buildMetricBaseline(
                    type: HKQuantityType(.restingHeartRate),
                    unit: .count().unitDivided(by: .minute())
                )
            },
            unit: "bpm"
        )

        async let spo2Reading = buildReading(
            fetcher: { try await manager.fetchLatestBloodOxygen() },
            baselineBuilder: {
                try await manager.buildMetricBaseline(
                    type: HKQuantityType(.oxygenSaturation),
                    unit: .percent(),
                    days: 30
                )
            },
            unit: "%"
        )

        async let respReading = buildReading(
            fetcher: { try await manager.fetchLatestRespiratoryRate() },
            baselineBuilder: {
                try await manager.buildMetricBaseline(
                    type: HKQuantityType(.respiratoryRate),
                    unit: .count().unitDivided(by: .minute())
                )
            },
            unit: "breaths/min"
        )

        return await HealthMetrics(
            date: Date(),
            hrv: hrvReading,
            restingHR: rhrReading,
            bloodOxygen: spo2Reading,
            respiratoryRate: respReading,
            wristTemperature: nil  // Add separately for iOS 16+ check
        )
    }

    // MARK: - Private

    private static func buildReading(
        fetcher: () async throws -> Double?,
        baselineBuilder: () async throws -> MetricBaseline?,
        unit: String
    ) async -> MetricReading? {
        do {
            guard let value = try await fetcher() else { return nil }
            let baseline = try? await baselineBuilder()
            return MetricReading(value: value, unit: unit, baseline: baseline, date: Date())
        } catch {
            return nil
        }
    }
}
