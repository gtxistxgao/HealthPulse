import Foundation

/// Aggregated, UI-ready snapshot of the metrics shown on the dashboard.
///
/// Pure value type that bundles the recovery score, energy summary and the
/// latest physiological readings so a view can render everything from a single
/// piece of state. Individual readings are optional because any of them may be
/// unavailable for a given day.
struct DashboardSnapshot: Equatable, Hashable, Codable, Sendable {
    /// The recovery/readiness score.
    var recovery: RecoveryScore

    /// Energy expenditure summary.
    var energy: EnergySummary

    /// Latest heart-rate variability reading (ms).
    var hrv: Double?

    /// Latest resting heart rate reading (bpm).
    var rhr: Double?

    /// Latest blood-oxygen saturation reading (fraction, e.g. `0.98`).
    var spo2: Double?

    /// Latest respiratory rate reading (breaths per minute).
    var resp: Double?

    init(
        recovery: RecoveryScore,
        energy: EnergySummary,
        hrv: Double? = nil,
        rhr: Double? = nil,
        spo2: Double? = nil,
        resp: Double? = nil
    ) {
        self.recovery = recovery
        self.energy = energy
        self.hrv = hrv
        self.rhr = rhr
        self.spo2 = spo2
        self.resp = resp
    }

    /// A placeholder snapshot for the empty / first-launch state.
    static let placeholder = DashboardSnapshot(
        recovery: .insufficientData,
        energy: .zero
    )
}
