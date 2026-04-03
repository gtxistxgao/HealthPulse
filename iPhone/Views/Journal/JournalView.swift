import SwiftUI
import SwiftData

// MARK: - Journal View

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = JournalViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Today's Entry
                    TodayJournalSection(viewModel: viewModel)

                    // Mood Selector
                    MoodSelector(mood: $viewModel.mood)

                    // Notes
                    NotesSection(notes: $viewModel.notes)

                    // Save Button
                    Button {
                        viewModel.saveEntry()
                    } label: {
                        Text("Save Today's Entry")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    // Impact Analysis
                    if !viewModel.impacts.isEmpty {
                        ImpactAnalysisSection(impacts: viewModel.impacts)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Journal")
            .onAppear {
                viewModel.setModelContext(modelContext)
                viewModel.loadTodayEntry()
            }
        }
    }
}

// MARK: - Today's Tags

struct TodayJournalSection: View {
    @ObservedObject var viewModel: JournalViewModel

    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What happened today?", icon: "pencil.and.list.clipboard")

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(JournalTag.allCases) { tag in
                    TagButton(
                        tag: tag,
                        isSelected: viewModel.selectedTags.contains(tag.rawValue),
                        action: { viewModel.toggleTag(tag.rawValue) }
                    )
                }
            }
        }
        .padding()
    }
}

struct TagButton: View {
    let tag: JournalTag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tag.icon)
                    .font(.title3)
                Text(tag.localizedName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected
                ? (tag.isPositive ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                : Color(.systemGray6))
            .foregroundStyle(isSelected ? (tag.isPositive ? .green : .orange) : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected
                        ? (tag.isPositive ? Color.green : Color.orange)
                        : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Mood Selector

struct MoodSelector: View {
    @Binding var mood: Int

    let moods = [
        (1, "Terrible", "face.dashed"),
        (2, "Bad", "face.smiling.inverse"),
        (3, "Okay", "face.smiling"),
        (4, "Good", "sun.min"),
        (5, "Great", "sun.max.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "How do you feel?", icon: "face.smiling")

            HStack(spacing: 12) {
                ForEach(moods, id: \.0) { item in
                    Button {
                        mood = item.0
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.2)
                                .font(.title2)
                            Text(item.1)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(mood == item.0 ? Color.blue.opacity(0.2) : Color.clear)
                        .foregroundStyle(mood == item.0 ? .blue : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Notes

struct NotesSection: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notes", icon: "text.alignleft")

            TextField("Any additional notes about today...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }
}

// MARK: - Impact Analysis

struct ImpactAnalysisSection: View {
    let impacts: [TagImpact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Impact Analysis", icon: "chart.line.uptrend.xyaxis")
            Text("How your activities affect Recovery & Sleep")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(impacts) { impact in
                ImpactRow(impact: impact)
            }
        }
        .padding()
    }
}

struct ImpactRow: View {
    let impact: TagImpact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: impact.tag.icon)
                    .foregroundStyle(.blue)
                Text(impact.tag.localizedName)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(impact.occurrences) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                ImpactMetric(
                    label: "Recovery",
                    impact: impact.recoveryImpact
                )
                ImpactMetric(
                    label: "Sleep",
                    impact: impact.sleepImpact
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ImpactMetric: View {
    let label: String
    let impact: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%+.0f%%", impact))
                .font(.caption.bold())
                .foregroundStyle(impact >= 0 ? .green : .red)
        }
    }
}
