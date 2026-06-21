import Foundation

/// Computes a recovery/readiness score from today's physiological readings
/// relative to the user's rolling baseline.
///
/// The approach is z-score based: each metric is expressed as how many standard
/// deviations today's value sits from its recent mean, then mapped onto a
/// `0...100` scale. Heart-rate variability (HRV) and resting heart rate (RHR)
/// are combined with a fixed weighting to produce the final score.
///
/// Statelessness keeps the maths easy to test — every entry point is a pure
/// `static` function with no hidden dependencies.
enum RecoveryCalculator {
    /// Minimum number of distinct sampled days required before a score is
    /// considered meaningful. Below this the calculator reports an
    /// "insufficient data" state instead of a misleadingly precise number.
    static let minimumSampleDays = 14

    /// Weight applied to the HRV component of the combined score.
    static let hrvWeight = 0.6

    /// Weight applied to the RHR component of the combined score.
    static let rhrWeight = 0.4

    /// Neutral component score used when a metric cannot be evaluated (missing
    /// reading, missing baseline, or zero variance). Corresponds to a z-score
    /// of `0`, i.e. exactly at the baseline mean.
    static let neutralComponentScore = 50.0

    /// Computes a recovery score from today's readings against a precomputed
    /// `HealthBaseline`.
    ///
    /// - Parameters:
    ///   - todayHRV: Today's heart-rate variability (ms), or `nil` if missing.
    ///   - todayRHR: Today's resting heart rate (bpm), or `nil` if missing.
    ///   - baseline: The rolling baseline to score against.
    /// - Returns: A `RecoveryScore`. When `baseline.sampleDays` is below
    ///   ``minimumSampleDays`` the result is ``RecoveryScore/insufficientData``.
    static func score(
        todayHRV: Double?,
        todayRHR: Double?,
        baseline: HealthBaseline
    ) -> RecoveryScore {
        guard baseline.sampleDays >= minimumSampleDays else {
            return .insufficientData
        }

        // HRV: higher than baseline is better, so the deviation is signed
        // (today - mean).
        let hrvScore = componentScore(
            today: todayHRV,
            mean: baseline.avgHRV,
            standardDeviation: baseline.stdHRV,
            higherIsBetter: true
        )

        // RHR: lower than baseline is better, so the deviation is inverted
        // (mean - today).
        let rhrScore = componentScore(
            today: todayRHR,
            mean: baseline.avgRHR,
            standardDeviation: baseline.stdRHR,
            higherIsBetter: false
        )

        let recovery = hrvScore * hrvWeight + rhrScore * rhrWeight
        return RecoveryScore(score: recovery, level: level(for: recovery))
    }

    /// Convenience that builds a baseline from raw daily history using
    /// `Array+Stats`, then scores today's readings against it.
    ///
    /// The number of sampled days is taken as the smaller of the two history
    /// counts, since both metrics must be present for a day to contribute.
    ///
    /// - Parameters:
    ///   - todayHRV: Today's heart-rate variability (ms), or `nil` if missing.
    ///   - todayRHR: Today's resting heart rate (bpm), or `nil` if missing.
    ///   - hrvHistory: Recent daily HRV readings (ms).
    ///   - rhrHistory: Recent daily RHR readings (bpm).
    static func score(
        todayHRV: Double?,
        todayRHR: Double?,
        hrvHistory: [Double],
        rhrHistory: [Double]
    ) -> RecoveryScore {
        let baseline = HealthBaseline(
            avgHRV: hrvHistory.mean,
            stdHRV: hrvHistory.standardDeviation,
            avgRHR: rhrHistory.mean,
            stdRHR: rhrHistory.standardDeviation,
            sampleDays: min(hrvHistory.count, rhrHistory.count)
        )
        return score(todayHRV: todayHRV, todayRHR: todayRHR, baseline: baseline)
    }

    /// Maps a z-score onto a `0...100` scale, clamping to that range.
    ///
    /// A z-score of `0` maps to `50`; `±3` standard deviations map to the
    /// `0`/`100` extremes, beyond which the value is clamped.
    static func normalizeZScore(_ z: Double) -> Double {
        let scaled = (z + 3) / 6 * 100
        return min(max(scaled, 0), 100)
    }

    /// Buckets a `0...100` recovery score into a traffic-light level:
    /// green `67...100`, yellow `34...66`, red `0...33`.
    static func level(for score: Double) -> RecoveryScore.Level {
        switch score {
        case 67...:
            return .green
        case 34...:
            return .yellow
        default:
            return .red
        }
    }

    /// Scores a single metric. Returns ``neutralComponentScore`` when the
    /// reading, mean, or a usable (positive) standard deviation is unavailable.
    private static func componentScore(
        today: Double?,
        mean: Double?,
        standardDeviation: Double?,
        higherIsBetter: Bool
    ) -> Double {
        guard
            let today,
            let mean,
            let standardDeviation,
            standardDeviation > 0
        else {
            return neutralComponentScore
        }

        let deviation = higherIsBetter ? (today - mean) : (mean - today)
        let z = deviation / standardDeviation
        return normalizeZScore(z)
    }
}
