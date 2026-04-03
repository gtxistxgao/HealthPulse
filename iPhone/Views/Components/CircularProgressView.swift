import SwiftUI

// MARK: - Circular Progress Ring

struct CircularProgressView: View {
    let progress: Double     // 0-1
    let lineWidth: CGFloat
    let color: Color
    let size: CGFloat

    init(progress: Double, lineWidth: CGFloat = 10, color: Color = .blue, size: CGFloat = 100) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Metric Card

struct MetricCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let score: Double
    let maxScore: Double
    let label: String
    let color: Color
    let size: CGFloat

    init(score: Double, maxScore: Double = 100, label: String, color: Color, size: CGFloat = 90) {
        self.score = score
        self.maxScore = maxScore
        self.label = label
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            CircularProgressView(
                progress: score / maxScore,
                lineWidth: 8,
                color: color,
                size: size
            )

            VStack(spacing: 2) {
                if maxScore == 100 {
                    Text("\(Int(score))%")
                        .font(.title3.bold())
                } else {
                    Text(String(format: "%.1f", score))
                        .font(.title3.bold())
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
        }
        .padding(.top, 8)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
