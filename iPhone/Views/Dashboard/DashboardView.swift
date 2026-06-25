import SwiftUI

/// The app's home screen: a 2×2 summary grid (recovery, energy, and two
/// "coming soon" placeholders) above a row of supporting physiological
/// metrics (HRV / RHR / SpO₂ / respiratory rate).
///
/// The view is a thin shell over ``DashboardViewModel``: it reads the view
/// model's three-state surface (``DashboardViewModel/isLoading``,
/// ``DashboardViewModel/errorMessage`` and ``DashboardViewModel/snapshot``)
/// and renders a spinner, an authorization/empty-state guide, or the data.
/// ``load()`` is kicked off from `onAppear`.
struct DashboardView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    /// Observed so a runtime language switch invalidates `body`; lookups then go
    /// through this instance (the app's localization entry point) and pick up the
    /// newly selected language's copy.
    @EnvironmentObject private var localization: LocalizationManager

    /// Whether the language-selection sheet is presented.
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = viewModel.snapshot {
                    content(for: snapshot)
                } else if viewModel.isLoading {
                    loadingState
                } else {
                    guidanceState
                }
            }
            .navigationTitle(localization("dashboard.nav.today"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Primary content

    private func content(for snapshot: DashboardSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryGrid(for: snapshot)
                metricsSection(for: snapshot)
            }
            .padding()
        }
        .refreshable { await viewModel.load() }
    }

    /// The headline 2×2 grid.
    private func summaryGrid(for snapshot: DashboardSnapshot) -> some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 16) {
            recoveryCard(for: snapshot.recovery)
            energyCard(for: snapshot.energy)
            comingSoonCard(title: localization("dashboard.card.sleep.title"), systemImage: "bed.double.fill", tint: .indigo)
            comingSoonCard(title: localization("dashboard.card.load.title"), systemImage: "flame.fill", tint: .orange)
        }
    }

    /// Recovery score rendered as a grade-coloured ring.
    private func recoveryCard(for recovery: RecoveryScore) -> some View {
        SummaryCard(title: localization("dashboard.card.recovery.title"), systemImage: "heart.fill", tint: Self.color(for: recovery.level)) {
            if recovery.isInsufficientData {
                VStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(localization("dashboard.recovery.collecting"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
            } else {
                CircularProgressView(
                    value: recovery.score,
                    tint: Self.color(for: recovery.level),
                    caption: label(for: recovery.level)
                )
                .frame(height: 120)
            }
        }
    }

    /// Today's total energy expenditure in kilocalories.
    private func energyCard(for energy: EnergySummary) -> some View {
        SummaryCard(title: localization("dashboard.card.energy.title"), systemImage: "bolt.fill", tint: .green) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(energy.total.rounded()))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(localization("dashboard.energy.unit.kcal"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                // Active vs. resting kcal substituted into the localized template
                // (args: two Int kcal values) via the localization entry point.
                Text(localization(
                    "dashboard.energy.breakdown",
                    Int(energy.active.rounded()),
                    Int(energy.basal.rounded())
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(height: 120)
        }
    }

    /// Placeholder card for a metric that is not yet implemented.
    private func comingSoonCard(title: String, systemImage: String, tint: Color) -> some View {
        SummaryCard(title: title, systemImage: systemImage, tint: tint) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundStyle(tint.opacity(0.5))
                Text(localization("dashboard.card.comingSoon"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 120)
        }
    }

    /// The supporting metrics row (HRV / RHR / SpO₂ / respiratory rate).
    private func metricsSection(for snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization("dashboard.section.vitals"))
                .font(.headline)

            LazyVGrid(columns: Self.gridColumns, spacing: 12) {
                MetricCard(
                    title: localization("dashboard.metric.hrv.title"),
                    value: format(snapshot.hrv),
                    unit: localization("dashboard.metric.hrv.unit"),
                    systemImage: "waveform.path.ecg",
                    tint: .green
                )
                MetricCard(
                    title: localization("dashboard.metric.rhr.title"),
                    value: format(snapshot.rhr),
                    unit: localization("dashboard.metric.rhr.unit"),
                    systemImage: "heart.fill",
                    tint: .pink
                )
                MetricCard(
                    title: localization("dashboard.metric.spo2.title"),
                    value: format(snapshot.spo2),
                    unit: localization("dashboard.metric.spo2.unit"),
                    systemImage: "lungs.fill",
                    tint: .blue
                )
                MetricCard(
                    title: localization("dashboard.metric.resp.title"),
                    value: format(snapshot.resp),
                    unit: localization("dashboard.metric.resp.unit"),
                    systemImage: "wind",
                    tint: .teal
                )
            }
        }
    }

    // MARK: - Non-data states

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(localization("dashboard.loading"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Shown when there is no snapshot and no load in flight — typically a
    /// missing authorization or a first launch with no data yet.
    private var guidanceState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 52))
                .foregroundStyle(.pink)
            Text(localization("dashboard.guidance.welcome"))
                .font(.title3.bold())
            Text(viewModel.errorMessage ?? localization("dashboard.guidance.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localization("dashboard.guidance.reload")) {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Formatting helpers

    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    /// Formats an optional reading for display, rounding to a whole number and
    /// falling back to a placeholder when the value is missing.
    private func format(_ value: Double?) -> String {
        guard let value else { return localization("dashboard.metric.noValue") }
        return "\(Int(value.rounded()))"
    }

    /// Traffic-light colour for a recovery level.
    private static func color(for level: RecoveryScore.Level) -> Color {
        switch level {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    /// Short caption shown inside the recovery ring (良好 / 一般 / 偏低).
    private func label(for level: RecoveryScore.Level) -> String {
        switch level {
        case .green: return localization("recovery.level.green")
        case .yellow: return localization("recovery.level.yellow")
        case .red: return localization("recovery.level.red")
        }
    }
}

/// A titled card wrapper matching ``MetricCard``'s visual style, used for the
/// dashboard's headline summary tiles.
private struct SummaryCard<Content: View>: View {
    var title: String
    var systemImage: String
    var tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            content()
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(DashboardViewModel(healthKit: HealthKitManager()))
        .environmentObject(LocalizationManager())
}
