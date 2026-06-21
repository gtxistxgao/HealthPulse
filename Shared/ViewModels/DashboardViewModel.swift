import Foundation

/// Placeholder view model backing the dashboard screen.
///
/// This will hold the loaded `DashboardSnapshot` and drive the dashboard UI.
/// For now it is an empty `ObservableObject` so the app can compile and inject
/// it through the environment.
@MainActor
final class DashboardViewModel: ObservableObject {
    /// The latest computed dashboard snapshot, once loading is implemented.
    @Published private(set) var snapshot: DashboardSnapshot?

    private let healthKit: HealthKitManager

    init(healthKit: HealthKitManager) {
        self.healthKit = healthKit
    }

    /// Load and compute the dashboard data.
    ///
    /// Intentionally a no-op placeholder for this stage.
    func load() async {}
}
