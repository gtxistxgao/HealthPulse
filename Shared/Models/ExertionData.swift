import Foundation

// MARK: - Exertion / Strain Model

struct ExertionData: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double              // 0-10 scale
    let rawTRIMP: Double           // raw training impulse value
    let zoneDurations: [HeartRateZoneDuration]
    let targetZone: ExertionTarget?

    var level: ExertionLevel {
        switch score {
        case 7...10:  return .high
        case 4..<7:   return .moderate
        case 1..<4:   return .light
        default:      return .rest
        }
    }
}

enum ExertionLevel: String {
    case high = "High"
    case moderate = "Moderate"
    case light = "Light"
    case rest = "Rest"

    var localizedName: String {
        switch self {
        case .high:     return "高强度"
        case .moderate: return "中等"
        case .light:    return "轻度"
        case .rest:     return "休息"
        }
    }

    var color: String {
        switch self {
        case .high:     return "exertionHigh"
        case .moderate: return "exertionModerate"
        case .light:    return "exertionLight"
        case .rest:     return "exertionRest"
        }
    }
}

// MARK: - Heart Rate Zones

struct HeartRateZoneDuration: Identifiable {
    let id = UUID()
    let zone: HeartRateZone
    let durationMinutes: Double
}

enum HeartRateZone: Int, CaseIterable {
    case zone1 = 1  // 50-59% HRR
    case zone2 = 2  // 60-69% HRR
    case zone3 = 3  // 70-79% HRR
    case zone4 = 4  // 80-89% HRR
    case zone5 = 5  // 90-100% HRR

    var weight: Double {
        switch self {
        case .zone1: return 1.0
        case .zone2: return 1.5
        case .zone3: return 2.0
        case .zone4: return 3.0
        case .zone5: return 5.0
        }
    }

    var name: String {
        switch self {
        case .zone1: return "Zone 1"
        case .zone2: return "Zone 2"
        case .zone3: return "Zone 3"
        case .zone4: return "Zone 4"
        case .zone5: return "Zone 5"
        }
    }

    var description: String {
        switch self {
        case .zone1: return "Very Light"
        case .zone2: return "Light"
        case .zone3: return "Moderate"
        case .zone4: return "Hard"
        case .zone5: return "Maximum"
        }
    }

    var color: String {
        switch self {
        case .zone1: return "zone1Color"
        case .zone2: return "zone2Color"
        case .zone3: return "zone3Color"
        case .zone4: return "zone4Color"
        case .zone5: return "zone5Color"
        }
    }

    /// Heart rate range as percentage of Heart Rate Reserve
    var hrrRange: ClosedRange<Double> {
        switch self {
        case .zone1: return 0.50...0.59
        case .zone2: return 0.60...0.69
        case .zone3: return 0.70...0.79
        case .zone4: return 0.80...0.89
        case .zone5: return 0.90...1.00
        }
    }
}

// MARK: - Target Exertion

struct ExertionTarget {
    let minScore: Double
    let maxScore: Double
    let basedOnRecovery: Double
    let trainingGoal: TrainingGoal

    var range: String {
        String(format: "%.1f - %.1f", minScore, maxScore)
    }
}

enum TrainingGoal: String, CaseIterable, Identifiable {
    case performance = "Performance"
    case maintain = "Maintain"
    case recovery = "Recovery"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .performance: return "增强表现"
        case .maintain:    return "维持体能"
        case .recovery:    return "恢复为主"
        }
    }
}
