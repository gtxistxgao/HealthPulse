import Foundation

// MARK: - Recovery Score Model

struct RecoveryData: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double          // 0-100
    let hrvValue: Double       // HRV in ms
    let rhrValue: Double       // Resting HR in bpm
    let hrvScore: Double       // 0-100
    let rhrScore: Double       // 0-100

    var level: RecoveryLevel {
        switch score {
        case 67...100: return .green
        case 34..<67:  return .yellow
        default:       return .red
        }
    }
}

enum RecoveryLevel: String {
    case green = "Good"
    case yellow = "Moderate"
    case red = "Low"

    var color: String {
        switch self {
        case .green:  return "recoveryGreen"
        case .yellow: return "recoveryYellow"
        case .red:    return "recoveryRed"
        }
    }

    var emoji: String {
        switch self {
        case .green:  return "checkmark.circle.fill"
        case .yellow: return "exclamationmark.circle.fill"
        case .red:    return "xmark.circle.fill"
        }
    }

    var suggestion: String {
        switch self {
        case .green:  return "Body well recovered. Great day for high intensity training!"
        case .yellow: return "Moderate recovery. Consider medium intensity activity."
        case .red:    return "Recovery is low. Rest or light activity recommended."
        }
    }

    var localizedName: String {
        switch self {
        case .green:  return "良好"
        case .yellow: return "一般"
        case .red:    return "较差"
        }
    }
}

// MARK: - Baseline data for personalized calculations

struct HealthBaseline {
    var avgHRV: Double = 0
    var stdHRV: Double = 0
    var avgRHR: Double = 0
    var stdRHR: Double = 0
    var maxHR: Double = 0
    var sampleDays: Int = 0

    var isReady: Bool { sampleDays >= 7 }
}
