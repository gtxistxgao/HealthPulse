import Foundation
import HealthKit

// MARK: - Sleep Score Analyzer

/// Analyzes sleep quality based on multiple dimensions from HealthKit sleep data.
///
/// Scoring weights:
/// - Duration (25%): Match to target (7-9 hours)
/// - Deep sleep (20%): Ideal 15-25% of total
/// - REM sleep (20%): Ideal 20-25% of total
/// - Sleep efficiency (15%): Time asleep / time in bed
/// - Interruptions (10%): Fewer is better
/// - Time to fall asleep (10%): Shorter is better
struct SleepAnalyzer {

    static let defaultTargetHours: Double = 8.0

    /// Analyze sleep samples from HealthKit
    static func analyze(samples: [HKCategorySample], targetHours: Double = 8.0) -> SleepData {
        // Categorize samples by sleep stage
        var remMinutes: Double = 0
        var deepMinutes: Double = 0
        var coreMinutes: Double = 0
        var awakeMinutes: Double = 0
        var inBedMinutes: Double = 0
        var interruptions = 0

        var sleepStart: Date?
        var sleepEnd: Date?
        var inBedStart: Date?

        var lastStageWasAwake = false

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0

            switch sample.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                inBedMinutes += duration
                if inBedStart == nil { inBedStart = sample.startDate }

            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remMinutes += duration
                trackSleepBounds(start: sample.startDate, end: sample.endDate,
                                 sleepStart: &sleepStart, sleepEnd: &sleepEnd)
                if lastStageWasAwake { interruptions += 1 }
                lastStageWasAwake = false

            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepMinutes += duration
                trackSleepBounds(start: sample.startDate, end: sample.endDate,
                                 sleepStart: &sleepStart, sleepEnd: &sleepEnd)
                if lastStageWasAwake { interruptions += 1 }
                lastStageWasAwake = false

            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreMinutes += duration
                trackSleepBounds(start: sample.startDate, end: sample.endDate,
                                 sleepStart: &sleepStart, sleepEnd: &sleepEnd)
                if lastStageWasAwake { interruptions += 1 }
                lastStageWasAwake = false

            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeMinutes += duration
                lastStageWasAwake = true

            default:
                // .asleepUnspecified or other — count as core sleep
                coreMinutes += duration
            }
        }

        let totalSleep = remMinutes + deepMinutes + coreMinutes
        let totalInBed = max(inBedMinutes, totalSleep + awakeMinutes)

        // Calculate sub-scores
        let durationScore = scoreDuration(totalMinutes: totalSleep, target: targetHours * 60)
        let deepScore = scorePercentage(actual: deepMinutes / max(totalSleep, 1) * 100,
                                        idealMin: 15, idealMax: 25)
        let remScore = scorePercentage(actual: remMinutes / max(totalSleep, 1) * 100,
                                       idealMin: 20, idealMax: 25)
        let efficiencyScore = totalInBed > 0 ? min(100, (totalSleep / totalInBed) * 100) : 0
        let interruptionScore = scoreInterruptions(count: interruptions)

        // Time to fall asleep
        let timeToSleep: Double
        if let bedStart = inBedStart, let firstSleep = sleepStart {
            timeToSleep = firstSleep.timeIntervalSince(bedStart) / 60.0
        } else {
            timeToSleep = 0
        }
        let fallAsleepScore = scoreFallAsleep(minutes: timeToSleep)

        // Weighted total
        let score = durationScore * 0.25
            + deepScore * 0.20
            + remScore * 0.20
            + efficiencyScore * 0.15
            + interruptionScore * 0.10
            + fallAsleepScore * 0.10

        let efficiency = totalInBed > 0 ? totalSleep / totalInBed : 0

        return SleepData(
            date: Date(),
            score: min(100, max(0, score)),
            totalSleepMinutes: totalSleep,
            inBedMinutes: totalInBed,
            remMinutes: remMinutes,
            deepMinutes: deepMinutes,
            coreMinutes: coreMinutes,
            awakeMinutes: awakeMinutes,
            interruptions: interruptions,
            sleepEfficiency: efficiency,
            heartRateDip: nil  // Calculated separately if HR data available
        )
    }

    /// Extract sleep stages for timeline visualization
    static func extractStages(from samples: [HKCategorySample]) -> [SleepStage] {
        samples.compactMap { sample in
            let stageType: SleepStageType?
            switch sample.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                stageType = .awake
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                stageType = .rem
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                stageType = .core
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                stageType = .deep
            default:
                stageType = nil
            }
            guard let stage = stageType else { return nil }
            return SleepStage(startDate: sample.startDate, endDate: sample.endDate, stage: stage)
        }
    }

    /// Calculate sleep debt over the last 7 days
    static func calculateSleepDebt(last7DaysMinutes: [Double], targetHours: Double = 8.0) -> SleepDebt {
        let hours = last7DaysMinutes.map { $0 / 60.0 }
        return SleepDebt(targetHours: targetHours, last7DaysActual: hours)
    }

    // MARK: - Sub-score Calculations

    /// Score based on how close actual duration is to target
    private static func scoreDuration(totalMinutes: Double, target: Double) -> Double {
        let ratio = totalMinutes / max(target, 1)
        // Perfect at 100%, drops off linearly
        if ratio >= 0.875 && ratio <= 1.125 {
            return 100  // Within ±12.5% of target
        } else if ratio < 0.875 {
            return max(0, ratio / 0.875 * 100)
        } else {
            // Oversleeping also reduces score slightly
            return max(50, 100 - (ratio - 1.125) * 200)
        }
    }

    /// Score based on whether a percentage falls within ideal range
    private static func scorePercentage(actual: Double, idealMin: Double, idealMax: Double) -> Double {
        if actual >= idealMin && actual <= idealMax {
            return 100
        } else if actual < idealMin {
            return max(0, actual / idealMin * 100)
        } else {
            return max(50, 100 - (actual - idealMax) * 5)
        }
    }

    /// Score interruptions (0 = 100, 5+ = 0)
    private static func scoreInterruptions(count: Int) -> Double {
        return max(0, 100 - Double(count) * 20)
    }

    /// Score time to fall asleep (< 10min = 100, > 30min = 0)
    private static func scoreFallAsleep(minutes: Double) -> Double {
        if minutes <= 10 { return 100 }
        if minutes >= 30 { return 0 }
        return (30 - minutes) / 20 * 100
    }

    // MARK: - Helper

    private static func trackSleepBounds(start: Date, end: Date,
                                          sleepStart: inout Date?, sleepEnd: inout Date?) {
        if sleepStart == nil || start < sleepStart! { sleepStart = start }
        if sleepEnd == nil || end > sleepEnd! { sleepEnd = end }
    }
}
