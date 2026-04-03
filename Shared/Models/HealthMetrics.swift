import Foundation

// MARK: - Health Monitoring Model

struct HealthMetrics {
    let date: Date
    let hrv: MetricReading?
    let restingHR: MetricReading?
    let bloodOxygen: MetricReading?
    let respiratoryRate: MetricReading?
    let wristTemperature: MetricReading?
}

struct MetricReading: Identifiable {
    let id = UUID()
    let value: Double
    let unit: String
    let baseline: MetricBaseline?
    let date: Date

    var status: MetricStatus {
        guard let baseline = baseline else { return .normal }
        let z = abs(value - baseline.mean) / max(baseline.stdDev, 0.001)
        if z > 2.0 { return .abnormal }
        if z > 1.5 { return .elevated }
        return .normal
    }

    var normalRange: String {
        guard let baseline = baseline else { return "—" }
        let low = baseline.mean - baseline.stdDev
        let high = baseline.mean + baseline.stdDev
        return String(format: "%.0f - %.0f %@", low, high, unit)
    }
}

struct MetricBaseline {
    let mean: Double
    let stdDev: Double
    let sampleCount: Int
}

enum MetricStatus: String {
    case normal = "Normal"
    case elevated = "Elevated"
    case abnormal = "Abnormal"

    var localizedName: String {
        switch self {
        case .normal:   return "正常"
        case .elevated: return "偏高/偏低"
        case .abnormal: return "异常"
        }
    }

    var color: String {
        switch self {
        case .normal:   return "metricNormal"
        case .elevated: return "metricElevated"
        case .abnormal: return "metricAbnormal"
        }
    }

    var icon: String {
        switch self {
        case .normal:   return "checkmark.circle.fill"
        case .elevated: return "exclamationmark.triangle.fill"
        case .abnormal: return "xmark.octagon.fill"
        }
    }
}

// MARK: - Trend data for charts

struct MetricTrend: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
