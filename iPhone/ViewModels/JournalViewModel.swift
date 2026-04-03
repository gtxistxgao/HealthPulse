import Foundation
import SwiftData
import SwiftUI

// MARK: - Journal ViewModel

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var todayEntry: JournalEntry?
    @Published var selectedTags: Set<String> = []
    @Published var notes: String = ""
    @Published var mood: Int = 3
    @Published var impacts: [TagImpact] = []

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - CRUD

    func loadTodayEntry() {
        guard let context = modelContext else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            todayEntry = existing
            selectedTags = Set(existing.tags)
            notes = existing.notes
            mood = existing.mood
        }
    }

    func saveEntry() {
        guard let context = modelContext else { return }

        if let existing = todayEntry {
            existing.tags = Array(selectedTags)
            existing.notes = notes
            existing.mood = mood
        } else {
            let entry = JournalEntry(
                date: Date(),
                tags: Array(selectedTags),
                notes: notes,
                mood: mood
            )
            context.insert(entry)
            todayEntry = entry
        }

        try? context.save()
    }

    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    // MARK: - Impact Analysis

    /// Analyze how journal tags correlate with Recovery and Sleep scores
    /// This is a simplified correlation — compares average Recovery/Sleep
    /// on days WITH a tag vs days WITHOUT the tag
    func analyzeImpacts(recoveryHistory: [(date: Date, score: Double)],
                         sleepHistory: [(date: Date, score: Double)]) {
        guard let context = modelContext else { return }

        // Fetch all journal entries
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let entries = try? context.fetch(descriptor), entries.count >= 7 else {
            impacts = []
            return
        }

        // Build date → scores lookup
        let calendar = Calendar.current
        var recoveryByDate: [Date: Double] = [:]
        var sleepByDate: [Date: Double] = [:]

        for r in recoveryHistory {
            recoveryByDate[calendar.startOfDay(for: r.date)] = r.score
        }
        for s in sleepHistory {
            sleepByDate[calendar.startOfDay(for: s.date)] = s.score
        }

        // For each tag, compare days with vs without
        var results: [TagImpact] = []

        for tag in JournalTag.allCases {
            let daysWithTag = entries.filter { $0.tags.contains(tag.rawValue) }
            let daysWithoutTag = entries.filter { !$0.tags.contains(tag.rawValue) }

            guard daysWithTag.count >= 3, daysWithoutTag.count >= 3 else { continue }

            // Get next-day Recovery (tag affects next morning's recovery)
            let recoveryWith = averageNextDay(entries: daysWithTag, scores: recoveryByDate)
            let recoveryWithout = averageNextDay(entries: daysWithoutTag, scores: recoveryByDate)

            // Get same-night Sleep score
            let sleepWith = averageSameDay(entries: daysWithTag, scores: sleepByDate)
            let sleepWithout = averageSameDay(entries: daysWithoutTag, scores: sleepByDate)

            results.append(TagImpact(
                tag: tag,
                avgRecoveryWith: recoveryWith,
                avgRecoveryWithout: recoveryWithout,
                avgSleepWith: sleepWith,
                avgSleepWithout: sleepWithout,
                occurrences: daysWithTag.count
            ))
        }

        // Sort by absolute impact
        impacts = results.sorted { abs($0.recoveryImpact) > abs($1.recoveryImpact) }
    }

    private func averageNextDay(entries: [JournalEntry], scores: [Date: Double]) -> Double {
        let calendar = Calendar.current
        let values = entries.compactMap { entry -> Double? in
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: entry.date))!
            return scores[nextDay]
        }
        return values.isEmpty ? 0 : values.mean
    }

    private func averageSameDay(entries: [JournalEntry], scores: [Date: Double]) -> Double {
        let calendar = Calendar.current
        let values = entries.compactMap { entry -> Double? in
            scores[calendar.startOfDay(for: entry.date)]
        }
        return values.isEmpty ? 0 : values.mean
    }
}
