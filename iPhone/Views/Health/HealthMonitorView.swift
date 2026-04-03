import SwiftUI
import Charts

// MARK: - Health Monitor View

struct HealthMonitorView: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let metrics = viewModel.healthMetrics {
                        // Overview status
                        HealthOverviewCard(metrics: metrics)

                        // Individual metric cards
                        if let hrv = metrics.hrv {
                            HealthMetricCard(
                                name: "Heart Rate Variability",
                                icon: "waveform.path.ecg",
                                reading: hrv,
                                description: "Measures autonomic nervous system function. Higher values generally indicate better recovery.",
                                color: .purple
                            )
                        }

                        if let rhr = metrics.restingHR {
                            HealthMetricCard(
                                name: "Resting Heart Rate",
                                icon: "heart.fill",
                                reading: rhr,
                                description: "Lower values typically indicate better cardiovascular fitness.",
                                color: .red
                            )
                        }

                        if let spo2 = metrics.bloodOxygen {
                            HealthMetricCard(
                                name: "Blood Oxygen",
                                icon: "lungs.fill",
                                reading: spo2,
                                description: "Normal range is 95-100%. Values below 95% may need medical attention.",
                                color: .blue
                            )
                        }

                        if let resp = metrics.respiratoryRate {
                            HealthMetricCard(
                                name: "Respiratory Rate",
                                icon: "wind",
                                reading: resp,
                                description: "Normal adult range is 12-20 breaths per minute at rest.",
                                color: .teal
                            )
                        }

                        if let temp = metrics.wristTemperature {
                            HealthMetricCard(
                                name: "Wrist Temperature",
                                icon: "thermometer.medium",
                                reading: temp,
                                description: "Deviation from your baseline. Useful for tracking illness or cycle patterns.",
                                color: .orange
                            )
                        }

                    } else {
                        EmptyStateView(
                            icon: "waveform.path.ecg",
                            title: "No Health Data",
                            message: "Health metrics will appear here once your Apple Watch collects enough data."
                        )
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .navigationTitle("Health")
        }
    }
}

// MARK: - Health Overview

struct HealthOverviewCard: View {
    let metrics: HealthMetrics

    var body: some View {
        let allReadings = [metrics.hrv, metrics.restingHR, metrics.bloodOxygen, metrics.respiratoryRate].compactMap { $0 }
        let abnormalCount = allReadings.filter { $0.status == .abnormal }.count
        let elevatedCount = allReadings.filter { $0.status == .elevated }.count

        HStack(spacing: 16) {
            Image(systemName: abnormalCount > 0 ? "exclamationmark.triangle.fill" :
                    elevatedCount > 0 ? "exclamationmark.circle.fill" :
                    "checkmark.shield.fill")
                .font(.title)
                .foregroundStyle(abnormalCount > 0 ? .red :
                                    elevatedCount > 0 ? .orange : .green)

            VStack(alignment: .leading, spacing: 4) {
                Text(abnormalCount > 0 ? "Attention Needed" :
                        elevatedCount > 0 ? "Some Metrics Elevated" :
                        "All Metrics Normal")
                    .font(.headline)

                Text(abnormalCount > 0
                     ? "\(abnormalCount) metric(s) outside normal range"
                     : elevatedCount > 0
                     ? "\(elevatedCount) metric(s) slightly elevated"
                     : "All metrics within your normal range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(abnormalCount > 0 ? Color.red.opacity(0.1) :
                        elevatedCount > 0 ? Color.orange.opacity(0.1) :
                        Color.green.opacity(0.1))
        )
    }
}

// MARK: - Individual Metric Card

struct HealthMetricCard: View {
    let name: String
    let icon: String
    let reading: MetricReading
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(name)
                    .font(.headline)
                Spacer()
                Image(systemName: reading.status.icon)
                    .foregroundStyle(statusColor)
            }

            // Value
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: reading.value >= 100 ? "%.0f" : "%.1f", reading.value))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(reading.unit)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Normal range
            if let baseline = reading.baseline {
                HStack {
                    Text("Your normal range:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(reading.normalRange)
                        .font(.caption.bold())
                }
            }

            // Status message
            HStack {
                Text(reading.status.localizedName)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)

                Text("  |  ")
                    .foregroundStyle(.quaternary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusColor: Color {
        switch reading.status {
        case .normal:   return .green
        case .elevated: return .orange
        case .abnormal: return .red
        }
    }
}
