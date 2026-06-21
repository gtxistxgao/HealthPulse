import Foundation

/// Placeholder for the HealthKit integration layer.
///
/// This will eventually wrap `HKHealthStore`, handle authorization, and stream
/// samples into the app. For now it is an empty `ObservableObject` so the app
/// can compile and inject it through the environment.
@MainActor
final class HealthKitManager: ObservableObject {
    /// Whether the user has granted access to the requested health data.
    @Published private(set) var isAuthorized = false

    init() {}

    /// Request authorization for the health data types the app needs.
    ///
    /// Intentionally a no-op placeholder for this stage.
    func requestAuthorization() async {}
}
