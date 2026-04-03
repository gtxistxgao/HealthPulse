import Foundation

// MARK: - Exertion / Strain Calculator

/// Calculates daily Exertion score (0-10) using a modified TRIMP
/// (Training Impulse) algorithm based on heart rate zone durations.
///
/// Steps:
/// 1. Determine personal HR zones using max HR and resting HR
/// 2. Accumulate time in each zone × zone weight
/// 3. Normalize raw TRIMP to 0-10 using 30-day personal history
struct ExertionCalculator {

    /// Calculate exertion from heart rate samples
    /// - Parameters:
    ///   - hrSamples: Array of (date, bpm) heart rate readings throughout the day
    ///   - baseline: Personal baseline containing maxHR and avgRHR
    ///   - historicalMax: Maximum raw TRIMP from the past 30 days (for normalization)
    /// - Returns: ExertionData with score and zone breakdowns
    static func calculate(
        hrSamples: [(date: Date, bpm: Double)],
        baseline: HealthBaseline,
        historicalMax: Double? = nil
    ) -> ExertionData {
        guard !hrSamples.isEmpty, baseline.maxHR > 0, baseline.avgRHR > 0 else {
            return ExertionData(
                date: Date(),
                score: 0,
                rawTRIMP: 0,
                zoneDurations: [],
                targetZone: nil
            )
        }

        let hrr = baseline.maxHR - baseline.avgRHR  // Heart Rate Reserve
        guard hrr > 0 else {
            return ExertionData(date: Date(), score: 0, rawTRIMP: 0, zoneDurations: [], targetZone: nil)
        }

        // Calculate time in each zone
        var zoneTimes: [HeartRateZone: Double] = [:]
        for zone in HeartRateZone.allCases {
            zoneTimes[zone] = 0
        }

        // Process consecutive HR samples to estimate duration in each zone
        for i in 0..<hrSamples.count {
            let bpm = hrSamples[i].bpm
            let hrrPercent = (bpm - baseline.avgRHR) / hrr

            // Determine which zone this HR falls into
            guard let zone = zoneForHRRPercent(hrrPercent) else { continue }

            // Estimate duration: use gap to next sample, capped at 10 minutes
            let duration: Double
            if i + 1 < hrSamples.count {
                let gap = hrSamples[i + 1].date.timeIntervalSince(hrSamples[i].date) / 60.0
                duration = min(gap, 10.0)  // Cap at 10 minutes
            } else {
                duration = 1.0  // Last sample: assume 1 minute
            }

            zoneTimes[zone, default: 0] += duration
        }

        // Calculate raw TRIMP
        var rawTRIMP: Double = 0
        var zoneDurations: [HeartRateZoneDuration] = []

        for zone in HeartRateZone.allCases {
            let minutes = zoneTimes[zone] ?? 0
            rawTRIMP += minutes * zone.weight
            zoneDurations.append(HeartRateZoneDuration(zone: zone, durationMinutes: minutes))
        }

        // Normalize to 0-10 scale
        let maxTRIMP = historicalMax ?? 500  // Default max if no history
        let normalizedScore = min(10.0, (rawTRIMP / max(maxTRIMP, 1)) * 10.0)

        return ExertionData(
            date: Date(),
            score: normalizedScore,
            rawTRIMP: rawTRIMP,
            zoneDurations: zoneDurations,
            targetZone: nil
        )
    }

    /// Calculate the maximum raw TRIMP from historical daily values
    /// Used for normalizing current day's score
    static func historicalMaxTRIMP(
        dailyHRSamples: [[(date: Date, bpm: Double)]],
        baseline: HealthBaseline
    ) -> Double {
        var maxTRIMP: Double = 0

        for daySamples in dailyHRSamples {
            let result = calculate(hrSamples: daySamples, baseline: baseline)
            maxTRIMP = max(maxTRIMP, result.rawTRIMP)
        }

        return max(maxTRIMP, 100)  // Minimum floor to avoid extreme scaling
    }

    // MARK: - Heart Rate Zone Determination

    /// Determine the heart rate zone for a given %HRR value
    private static func zoneForHRRPercent(_ percent: Double) -> HeartRateZone? {
        switch percent {
        case 0.90...1.5:  return .zone5   // Allow slightly over 100%
        case 0.80..<0.90: return .zone4
        case 0.70..<0.80: return .zone3
        case 0.60..<0.70: return .zone2
        case 0.50..<0.60: return .zone1
        default:          return nil       // Below threshold — not counted
        }
    }

    /// Get heart rate boundaries for each zone (for display purposes)
    static func zoneHeartRates(baseline: HealthBaseline) -> [(zone: HeartRateZone, minBPM: Int, maxBPM: Int)] {
        let hrr = baseline.maxHR - baseline.avgRHR
        return HeartRateZone.allCases.map { zone in
            let minBPM = Int(baseline.avgRHR + hrr * zone.hrrRange.lowerBound)
            let maxBPM = Int(baseline.avgRHR + hrr * zone.hrrRange.upperBound)
            return (zone: zone, minBPM: minBPM, maxBPM: maxBPM)
        }
    }
}
