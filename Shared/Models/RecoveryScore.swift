import Foundation

/// A single readiness/recovery reading derived from the user's recent
/// physiological baselines.
///
/// Pure value type with no behaviour beyond simple conveniences — the scoring
/// logic that produces a `RecoveryScore` lives elsewhere.
struct RecoveryScore: Equatable, Hashable, Codable, Sendable {
    /// Qualitative bucket for the recovery score, surfaced to the UI as a
    /// traffic-light indicator (绿 / 黄 / 红).
    enum Level: String, CaseIterable, Codable, Sendable {
        /// 绿 — well recovered.
        case green
        /// 黄 — moderate / caution.
        case yellow
        /// 红 — poorly recovered.
        case red
    }

    /// Normalised recovery score, conventionally in the range `0...100`.
    var score: Double

    /// Traffic-light bucket associated with `score`.
    var level: Level

    /// `true` when there were not enough samples to compute a meaningful
    /// score (e.g. a freshly installed app without baseline history).
    var isInsufficientData: Bool

    init(score: Double, level: Level, isInsufficientData: Bool = false) {
        self.score = score
        self.level = level
        self.isInsufficientData = isInsufficientData
    }

    /// A placeholder reading used while a real baseline is still being built.
    static let insufficientData = RecoveryScore(
        score: 0,
        level: .yellow,
        isInsufficientData: true
    )
}
