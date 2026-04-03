import SwiftUI

@main
struct HealthPulseWatchApp: App {
    @StateObject private var healthKit = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(healthKit)
                .task {
                    await healthKit.requestAuthorization()
                }
        }
    }
}
