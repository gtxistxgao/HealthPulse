import Foundation

// MARK: - Energy Burned Model

struct EnergyData: Identifiable {
    let id = UUID()
    let date: Date
    let activeCalories: Double
    let basalCalories: Double

    var totalCalories: Double { activeCalories + basalCalories }

    var activePercentage: Double {
        totalCalories > 0 ? activeCalories / totalCalories * 100 : 0
    }
}

// MARK: - Hourly breakdown for charts

struct HourlyEnergy: Identifiable {
    let id = UUID()
    let hour: Int         // 0-23
    let active: Double
    let basal: Double

    var total: Double { active + basal }
}
