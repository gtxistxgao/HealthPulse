import Foundation

/// Rolling statistical baseline for the metrics that drive recovery scoring.
///
/// The averages and standard deviations are optional because a baseline is
/// only meaningful once enough days of data have been collected; until then
/// the corresponding fields are `nil`.
struct HealthBaseline: Equatable, Hashable, Codable, Sendable {
    /// Mean heart-rate variability (ms) over the sampled window.
    var avgHRV: Double?

    /// Standard deviation of heart-rate variability (ms).
    var stdHRV: Double?

    /// Mean resting heart rate (bpm) over the sampled window.
    var avgRHR: Double?

    /// Standard deviation of resting heart rate (bpm).
    var stdRHR: Double?

    /// Number of distinct days that contributed to this baseline.
    var sampleDays: Int

    init(
        avgHRV: Double? = nil,
        stdHRV: Double? = nil,
        avgRHR: Double? = nil,
        stdRHR: Double? = nil,
        sampleDays: Int = 0
    ) {
        self.avgHRV = avgHRV
        self.stdHRV = stdHRV
        self.avgRHR = avgRHR
        self.stdRHR = stdRHR
        self.sampleDays = sampleDays
    }

    /// An empty baseline with no samples — the starting state for a new user.
    static let empty = HealthBaseline()
}
