import SwiftUI

/// A circular ring that visualises a `0...100` score with a colour that
/// reflects the score's qualitative grade (green / yellow / red).
///
/// Pure, self-contained SwiftUI — the only input is the numeric value; the
/// ring fraction, grade colour and centre label are all derived from it. The
/// caller may override the colour and centre content when a different
/// presentation is needed.
struct CircularProgressView<Label: View>: View {
    /// Score to display. Values outside `0...100` are clamped.
    var value: Double

    /// Stroke thickness of the ring.
    var lineWidth: CGFloat

    /// Explicit ring colour. When `nil` the colour is derived from `value`
    /// using the same green/yellow/red grading the rest of the app uses.
    var tint: Color?

    /// Centre content, defaulting to the rounded value (see the convenience
    /// initialiser below).
    @ViewBuilder var label: () -> Label

    init(
        value: Double,
        lineWidth: CGFloat = 12,
        tint: Color? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.value = value
        self.lineWidth = lineWidth
        self.tint = tint
        self.label = label
    }

    /// Fraction of the ring to fill, clamped to `0...1`.
    private var fraction: Double {
        min(max(value / 100, 0), 1)
    }

    /// Colour used for the filled portion of the ring.
    private var ringColor: Color {
        tint ?? Self.gradeColor(for: value)
    }

    /// Maps a `0...100` score onto the app's traffic-light palette.
    static func gradeColor(for value: Double) -> Color {
        switch value {
        case ..<50: return .red
        case ..<75: return .yellow
        default: return .green
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: fraction)

            label()
        }
        .padding(lineWidth / 2)
    }
}

extension CircularProgressView where Label == AnyView {
    /// Convenience initialiser that renders the rounded score and an optional
    /// caption in the centre of the ring.
    init(
        value: Double,
        lineWidth: CGFloat = 12,
        tint: Color? = nil,
        caption: String? = nil
    ) {
        self.init(value: value, lineWidth: lineWidth, tint: tint) {
            AnyView(
                VStack(spacing: 2) {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if let caption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            )
        }
    }
}

#Preview("Grades") {
    HStack(spacing: 16) {
        CircularProgressView(value: 88, caption: "Recovery")
        CircularProgressView(value: 62, caption: "Recovery")
        CircularProgressView(value: 34, caption: "Recovery")
    }
    .frame(height: 120)
    .padding()
}

#Preview("Custom centre") {
    CircularProgressView(value: 72, lineWidth: 16, tint: .blue) {
        Image(systemName: "bolt.fill")
            .font(.largeTitle)
            .foregroundStyle(.blue)
    }
    .frame(width: 160, height: 160)
    .padding()
}
