import Foundation

// MARK: - Sleep Analysis Model

struct SleepData: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double               // 0-100 overall quality
    let totalSleepMinutes: Double
    let inBedMinutes: Double
    let remMinutes: Double
    let deepMinutes: Double
    let coreMinutes: Double
    let awakeMinutes: Double
    let interruptions: Int
    let sleepEfficiency: Double     // actual sleep / in bed time (0-1)
    let heartRateDip: Double?       // percentage dip during sleep

    // Derived
    var totalSleepHours: Double { totalSleepMinutes / 60.0 }
    var inBedHours: Double { inBedMinutes / 60.0 }
    var remPercentage: Double { totalSleepMinutes > 0 ? remMinutes / totalSleepMinutes * 100 : 0 }
    var deepPercentage: Double { totalSleepMinutes > 0 ? deepMinutes / totalSleepMinutes * 100 : 0 }
    var corePercentage: Double { totalSleepMinutes > 0 ? coreMinutes / totalSleepMinutes * 100 : 0 }

    var level: SleepLevel {
        switch score {
        case 80...100: return .excellent
        case 60..<80:  return .good
        case 40..<60:  return .fair
        default:       return .poor
        }
    }
}

enum SleepLevel: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var localizedName: String {
        switch self {
        case .excellent: return "优秀"
        case .good:      return "良好"
        case .fair:      return "一般"
        case .poor:      return "较差"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "sleepExcellent"
        case .good:      return "sleepGood"
        case .fair:      return "sleepFair"
        case .poor:      return "sleepPoor"
        }
    }
}

struct SleepStage: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let stage: SleepStageType
}

enum SleepStageType: String, CaseIterable {
    case awake = "Awake"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"

    var color: String {
        switch self {
        case .awake: return "stageAwake"
        case .rem:   return "stageREM"
        case .core:  return "stageCore"
        case .deep:  return "stageDeep"
        }
    }

    var localizedName: String {
        switch self {
        case .awake: return "清醒"
        case .rem:   return "REM"
        case .core:  return "核心"
        case .deep:  return "深度"
        }
    }
}

// MARK: - Sleep Debt Tracking

struct SleepDebt {
    let targetHours: Double  // default 8.0
    let last7DaysActual: [Double]  // hours per night

    var totalDebt: Double {
        last7DaysActual.reduce(0) { $0 + max(0, targetHours - $1) }
    }

    var averageSleep: Double {
        guard !last7DaysActual.isEmpty else { return 0 }
        return last7DaysActual.reduce(0, +) / Double(last7DaysActual.count)
    }
}
