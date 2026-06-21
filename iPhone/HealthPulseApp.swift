import SwiftUI

@main
struct HealthPulseApp: App {
    /// Owns the HealthKit integration for the app lifetime.
    @StateObject private var healthKitManager: HealthKitManager

    /// Drives the dashboard screen.
    @StateObject private var dashboardViewModel: DashboardViewModel

    init() {
        let healthKit = HealthKitManager()
        _healthKitManager = StateObject(wrappedValue: healthKit)
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(healthKit: healthKit))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(healthKitManager)
                .environmentObject(dashboardViewModel)
        }
    }
}
