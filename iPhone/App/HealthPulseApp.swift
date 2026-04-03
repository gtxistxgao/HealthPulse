import SwiftUI
import SwiftData

@main
struct HealthPulseApp: App {
    @StateObject private var healthKit = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKit)
                .modelContainer(for: JournalEntry.self)
        }
    }
}

// MARK: - Root Content View with Tab Navigation

struct ContentView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @StateObject private var dashboardVM: DashboardViewModel

    init() {
        // Initialize with a temporary HealthKitManager;
        // the real one is injected via environment
        _dashboardVM = StateObject(wrappedValue: DashboardViewModel(healthKit: HealthKitManager()))
    }

    var body: some View {
        Group {
            if healthKit.isAuthorized {
                MainTabView()
                    .environmentObject(dashboardVM)
            } else {
                OnboardingView()
            }
        }
        .task {
            await healthKit.requestAuthorization()
            if healthKit.isAuthorized {
                // Re-initialize VM with proper HealthKit reference
                let vm = DashboardViewModel(healthKit: healthKit)
                await vm.loadAllData()
            }
        }
    }
}

// MARK: - Onboarding / Permission Request

struct OnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitManager

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("HealthPulse")
                .font(.largeTitle.bold())

            Text("Track your Recovery, Sleep, Exertion and Health metrics using your Apple Watch data.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                Task {
                    await healthKit.requestAuthorization()
                }
            } label: {
                Label("Connect Apple Health", systemImage: "heart.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 30)

            if let error = healthKit.authorizationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square")
                }

            SleepDetailView()
                .tabItem {
                    Label("Sleep", systemImage: "moon.fill")
                }

            ExertionDetailView()
                .tabItem {
                    Label("Exertion", systemImage: "flame.fill")
                }

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }

            HealthMonitorView()
                .tabItem {
                    Label("Health", systemImage: "waveform.path.ecg")
                }
        }
    }
}
