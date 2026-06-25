import SwiftUI

/// In-app language picker.
///
/// Lists a "follow the system language" option followed by every language the
/// app ships translations for (``LocalizationManager/supportedLanguages``),
/// each labelled with its own endonym so it is recognisable regardless of the
/// language currently in effect.
///
/// The current choice is read from the ``LocalizationManager`` in the
/// environment and marked with a trailing checkmark. Tapping a row switches the
/// language immediately: ``LocalizationManager`` republishes its `selection` /
/// `languageCode`, which re-renders this view (the checkmark moves) and the rest
/// of the app in the newly chosen language.
///
/// All chrome copy flows through the unified localization entry point
/// (``L(_:_:)``) so the screen's own text re-renders into the selected language
/// too; the language *names* themselves are intentionally shown verbatim as
/// endonyms rather than translated.
struct SettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        NavigationStack {
            List {
                Section(L("settings.language.header")) {
                    languageRow(
                        title: L("settings.language.system"),
                        isSelected: localization.isFollowingSystem
                    ) {
                        localization.followSystem()
                    }

                    ForEach(LocalizationManager.supportedLanguages) { language in
                        languageRow(
                            title: language.nativeName,
                            isSelected: !localization.isFollowingSystem
                                && localization.selection == language.code
                        ) {
                            localization.setLanguage(language)
                        }
                    }
                }
            }
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// A single selectable language row: a title, a trailing checkmark when it
    /// is the active choice, and a tap that performs the switch.
    ///
    /// The whole row is tappable (`contentShape`) and uses the plain button
    /// style so it reads as a list cell rather than a tinted button.
    private func languageRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityLabel(Text(verbatim: "✓"))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocalizationManager())
}
