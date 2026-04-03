import Foundation

// MARK: - Recovery Score Calculator

/// Calculates Recovery score (0-100%) based on HRV and Resting Heart Rate
/// compared to personal 60-day baseline.
///
/// Algorithm:
/// - HRV score (60% weight): Higher HRV = better recovery
/// - RHR score (40% weight): Lower RHR = better recovery
/// - Both compared to personal baseline using z-scores
struct RecoveryCalculator {

    /// Calculate today's Recovery score
    /// - Parameters:
    ///   - todayHRV: Today's HRV reading in milliseconds (SDNN)
    ///   - todayRHR: Today's resting heart rate in bpm
    ///   - baseline: 60-day personal baseline statistics
    /// - Returns: RecoveryData with score and breakdown
    static func calculate(todayHRV: Double, todayRHR: Double, baseline: HealthBaseline) -> RecoveryData {
        // Guard against division by zero or insufficient data
        guard baseline.stdHRV > 0, baseline.stdRHR > 0 else {
            return RecoveryData(
                date: Date(),
                score: 50,
                hrvValue: todayHRV,
                rhrValue: todayRHR,
                hrvScore: 50,
                rhrScore: 50
            )
        }

        // HRV: higher is better
        let hrvZ = (todayHRV - baseline.avgHRV) / baseline.stdHRV
        let hrvScore = normalizeZScore(hrvZ)

        // RHR: lower is better (reverse direction)
        let rhrZ = (baseline.avgRHR - todayRHR) / baseline.stdRHR
        let rhrScore = normalizeZScore(rhrZ)

        // Weighted combination (HRV slightly more important)
        let recovery = hrvScore * 0.6 + rhrScore * 0.4

        return RecoveryData(
            date: Date(),
            score: recovery,
            hrvValue: todayHRV,
            rhrValue: todayRHR,
            hrvScore: hrvScore,
            rhrScore: rhrScore
        )
    }

    /// Calculate target exertion zone based on recovery and training goal
    static func targetExertion(recoveryScore: Double, goal: TrainingGoal) -> ExertionTarget {
        let baseMin: Double
        let baseMax: Double

        switch goal {
        case .performance:
            baseMin = 5.0
            baseMax = 8.0
        case .maintain:
            baseMin = 3.0
            baseMax = 6.0
        case .recovery:
            baseMin = 1.0
            baseMax = 3.0
        }

        // Adjust based on recovery level
        let recoveryFactor: Double
        if recoveryScore >= 67 {
            recoveryFactor = 1.0      // Full range
        } else if recoveryScore >= 34 {
            recoveryFactor = 0.7      // Reduce by 30%
        } else {
            recoveryFactor = 0.4      // Reduce by 60%
        }

        let adjustedMin = max(0, baseMin * recoveryFactor)
        let adjustedMax = min(10, baseMax * recoveryFactor)

        return ExertionTarget(
            minScore: adjustedMin,
            maxScore: adjustedMax,
            basedOnRecovery: recoveryScore,
            trainingGoal: goal
        )
    }

    // MARK: - Private

    /// Maps a z-score to 0-100 range
    /// z = -3 → 0, z = 0 → 50, z = +3 → 100
    private static func normalizeZScore(_ z: Double) -> Double {
        let clamped = min(3.0, max(-3.0, z))
        return (clamped + 3.0) / 6.0 * 100.0
    }
}
