import Foundation

/// A summary of energy expenditure over some period, expressed in kilocalories.
///
/// Pure value type. `total` is derived from `active + basal` so the three
/// figures can never disagree.
struct EnergySummary: Equatable, Hashable, Codable, Sendable {
    /// Active energy burned (movement, exercise), in kilocalories.
    var active: Double

    /// Basal/resting energy burned, in kilocalories.
    var basal: Double

    /// Total energy burned — the sum of `active` and `basal`.
    var total: Double { active + basal }

    init(active: Double, basal: Double) {
        self.active = active
        self.basal = basal
    }

    /// An all-zero summary, useful as a default before any data is available.
    static let zero = EnergySummary(active: 0, basal: 0)
}
