import SwiftUI

@main
struct HealthPulseApp: App {
    /// Owns the HealthKit integration for the app lifetime.
    @StateObject private var healthKitManager: HealthKitManager

    /// Drives the dashboard screen.
    @StateObject private var dashboardViewModel: DashboardViewModel

    /// Owns the in-app language selection and backs the unified localized-text
    /// entry point (``L(_:_:)`` / ``Swift/String/localized(_:)``).
    @StateObject private var localizationManager = LocalizationManager()

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
                .environmentObject(localizationManager)
        }
    }
}
