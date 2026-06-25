import Foundation

/// View model backing the dashboard screen.
///
/// Drives the dashboard through a simple three-state surface — ``isLoading``,
/// ``errorMessage`` and ``snapshot`` — so a view can render a spinner, an error
/// or the data without inspecting anything else.
///
/// ``load()`` requests HealthKit authorization, then concurrently pulls the
/// rolling baseline history alongside today's readings and hands them to
/// ``RecoveryCalculator`` to assemble a ``DashboardSnapshot``.
@MainActor
final class DashboardViewModel: ObservableObject {
    /// Number of days of history used to build the recovery baseline.
    static let baselineDays = 60

    /// Whether a ``load()`` is currently in flight.
    @Published private(set) var isLoading = false

    /// A human-readable error message when the most recent load failed, else `nil`.
    @Published private(set) var errorMessage: String?

    /// The latest computed dashboard snapshot, once loading succeeds.
    @Published private(set) var snapshot: DashboardSnapshot?

    private let healthKit: HealthKitManager

    init(healthKit: HealthKitManager) {
        self.healthKit = healthKit
    }

    /// Load and compute the dashboard data.
    ///
    /// Authorizes first (HealthKit never throws on read denial — missing data is
    /// simply absent), then fetches the 60-day HRV/RHR baseline together with
    /// today's HRV, RHR, energy and the remaining vitals concurrently, and
    /// composes them into a ``DashboardSnapshot``.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        await healthKit.requestAuthorization()

        guard healthKit.isAuthorized else {
            errorMessage = String(localized: "healthkit.auth.denied")
            return
        }

        let today = Date()

        // Kick off the baseline history and today's readings concurrently; each
        // HealthKit read resolves independently so the slowest one bounds the
        // total wait rather than their sum.
        async let hrvHistory = healthKit.fetchHRVHistory(days: Self.baselineDays)
        async let rhrHistory = healthKit.fetchRHRHistory(days: Self.baselineDays)
        async let todayHRV = healthKit.fetchLatestHRV()
        async let todayRHR = healthKit.fetchLatestRHR()
        async let activeEnergy = healthKit.fetchActiveEnergy(for: today)
        async let basalEnergy = healthKit.fetchBasalEnergy(for: today)
        async let spo2 = healthKit.fetchLatestBloodOxygen()
        async let resp = healthKit.fetchLatestRespiratoryRate()

        let hrv = await todayHRV
        let rhr = await todayRHR

        let recovery = RecoveryCalculator.score(
            todayHRV: hrv,
            todayRHR: rhr,
            hrvHistory: await hrvHistory,
            rhrHistory: await rhrHistory
        )

        let energy = EnergySummary(
            active: await activeEnergy,
            basal: await basalEnergy
        )

        snapshot = DashboardSnapshot(
            recovery: recovery,
            energy: energy,
            hrv: hrv,
            rhr: rhr,
            spo2: await spo2,
            resp: await resp
        )
    }
}
