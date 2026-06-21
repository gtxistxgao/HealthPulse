import SwiftUI

/// A compact card surfacing a single metric: a title, a prominent value with an
/// optional unit, and an optional supporting subtitle. Optionally accented with
/// an SF Symbol.
///
/// Pure, self-contained SwiftUI suitable for use in grids and lists.
struct MetricCard: View {
    /// Short label describing the metric (e.g. "Resting HR").
    var title: String

    /// The headline value, already formatted for display (e.g. "58").
    var value: String

    /// Optional unit shown next to the value (e.g. "bpm").
    var unit: String?

    /// Optional supporting line below the value (e.g. a trend or baseline).
    var subtitle: String?

    /// Optional SF Symbol drawn alongside the title.
    var systemImage: String?

    /// Accent colour for the symbol.
    var tint: Color

    init(
        title: String,
        value: String,
        unit: String? = nil,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = .accentColor
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

#Preview("Grid") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        MetricCard(
            title: "Resting HR",
            value: "58",
            unit: "bpm",
            subtitle: "−3 vs baseline",
            systemImage: "heart.fill",
            tint: .pink
        )
        MetricCard(
            title: "HRV",
            value: "72",
            unit: "ms",
            subtitle: "+8 vs baseline",
            systemImage: "waveform.path.ecg",
            tint: .green
        )
        MetricCard(
            title: "Sleep",
            value: "7.4",
            unit: "h",
            systemImage: "bed.double.fill",
            tint: .indigo
        )
        MetricCard(
            title: "Steps",
            value: "8,210",
            systemImage: "figure.walk",
            tint: .orange
        )
    }
    .padding()
}
