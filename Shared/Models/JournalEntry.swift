import Foundation
import SwiftData

// MARK: - Journal Entry (persisted with SwiftData)

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var tags: [String]       // e.g. ["alcohol", "caffeine", "travel"]
    var notes: String
    var mood: Int            // 1-5 scale

    init(date: Date = .now, tags: [String] = [], notes: String = "", mood: Int = 3) {
        self.id = UUID()
        self.date = date
        self.tags = tags
        self.notes = notes
        self.mood = mood
    }
}

// MARK: - Available Journal Tags

enum JournalTag: String, CaseIterable, Identifiable {
    case alcohol = "alcohol"
    case caffeine = "caffeine"
    case travel = "travel"
    case lateNight = "late_night"
    case stress = "stress"
    case meditation = "meditation"
    case stretching = "stretching"
    case supplements = "supplements"
    case healthyEating = "healthy_eating"
    case screenTime = "screen_time"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alcohol:      return "Alcohol"
        case .caffeine:     return "Caffeine"
        case .travel:       return "Travel"
        case .lateNight:    return "Late Night"
        case .stress:       return "Stress"
        case .meditation:   return "Meditation"
        case .stretching:   return "Stretching"
        case .supplements:  return "Supplements"
        case .healthyEating: return "Healthy Eating"
        case .screenTime:   return "Screen Time"
        }
    }

    var localizedName: String {
        switch self {
        case .alcohol:      return "饮酒"
        case .caffeine:     return "咖啡因"
        case .travel:       return "旅行"
        case .lateNight:    return "熬夜"
        case .stress:       return "压力大"
        case .meditation:   return "冥想"
        case .stretching:   return "拉伸"
        case .supplements:  return "营养补充"
        case .healthyEating: return "健康饮食"
        case .screenTime:   return "屏幕时间"
        }
    }

    var icon: String {
        switch self {
        case .alcohol:      return "wineglass"
        case .caffeine:     return "cup.and.saucer"
        case .travel:       return "airplane"
        case .lateNight:    return "moon.stars"
        case .stress:       return "bolt.heart"
        case .meditation:   return "brain.head.profile"
        case .stretching:   return "figure.flexibility"
        case .supplements:  return "pills"
        case .healthyEating: return "leaf"
        case .screenTime:   return "iphone"
        }
    }

    /// Indicates if this tag is generally positive for health
    var isPositive: Bool {
        switch self {
        case .meditation, .stretching, .supplements, .healthyEating:
            return true
        default:
            return false
        }
    }
}

// MARK: - Impact Analysis Result

struct TagImpact: Identifiable {
    let id = UUID()
    let tag: JournalTag
    let avgRecoveryWith: Double
    let avgRecoveryWithout: Double
    let avgSleepWith: Double
    let avgSleepWithout: Double
    let occurrences: Int

    var recoveryImpact: Double { avgRecoveryWith - avgRecoveryWithout }
    var sleepImpact: Double { avgSleepWith - avgSleepWithout }
}
