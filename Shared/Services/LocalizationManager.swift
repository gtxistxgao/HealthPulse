import Foundation
import SwiftUI

/// Owns the app's in-app language selection and exposes the resources needed to
/// render UI in that language.
///
/// The user's choice is persisted as a single string under
/// ``UserDefaults`` and is one of two shapes:
///
/// - ``systemSelection`` (`"system"`, the default): follow the device. On every
///   launch the system's preferred languages are read and the first one that
///   maps to a ``supportedLanguages`` entry wins; if none match, the app falls
///   back to ``fallbackLanguageCode``.
/// - A concrete language code (e.g. `"en"`, `"zh-Hans"`): an explicit override.
///   Once the user picks a specific language the device's preferences are no
///   longer consulted — only that language is used until the user switches again
///   (including switching back to ``systemSelection``).
///
/// The *resolved* code is published as ``languageCode`` so SwiftUI views observing
/// this object refresh whenever the language changes, and the matching
/// ``bundle`` / ``locale`` are derived from it for `NSLocalizedString` lookups and
/// locale-aware formatting.
@MainActor
final class LocalizationManager: ObservableObject {
    /// A language the app ships translations for.
    struct SupportedLanguage: Identifiable, Hashable {
        /// The language code, matching the corresponding `<code>.lproj` folder
        /// (e.g. `"en"`, `"zh-Hans"`).
        let code: String
        /// The language's own endonym, suitable for a selection list
        /// (e.g. `"English"`, `"简体中文"`).
        let nativeName: String

        var id: String { code }
    }

    /// Every language the app supports, defined in one place so a settings
    /// picker and the resolution logic share a single source of truth.
    static let supportedLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "en", nativeName: "English"),
        SupportedLanguage(code: "zh-Hans", nativeName: "简体中文"),
    ]

    /// The stored value meaning "follow the system language".
    static let systemSelection = "system"

    /// The language used when following the system but no preferred language
    /// matches a supported one.
    static let fallbackLanguageCode = "en"

    /// `UserDefaults` key under which the raw selection is persisted.
    private static let storageKey = "HealthPulse.selectedLanguage"

    /// The resolved language code currently in effect (always a concrete,
    /// supported code — never ``systemSelection``).
    ///
    /// Published so SwiftUI views re-render when the language changes.
    @Published private(set) var languageCode: String

    /// The raw persisted selection: either ``systemSelection`` or a concrete
    /// supported language code. Drives a settings picker's current value.
    @Published private(set) var selection: String

    private let defaults: UserDefaults

    /// - Parameter defaults: the store to read/write the selection from. Injected
    ///   so tests can supply an isolated suite; defaults to `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.storageKey) ?? Self.systemSelection
        self.selection = stored
        self.languageCode = Self.resolve(selection: stored)
    }

    // MARK: - Derived resources

    /// `true` when the app is following the device's language preference.
    var isFollowingSystem: Bool {
        selection == Self.systemSelection
    }

    /// The bundle whose `.lproj` matches ``languageCode``, used as the lookup
    /// table for localized strings. Falls back to `Bundle.main` when the
    /// matching `.lproj` is absent (e.g. resources not yet added), so lookups
    /// degrade gracefully rather than crashing.
    var bundle: Bundle {
        guard
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }

    /// The `Locale` for ``languageCode``, for locale-aware formatting.
    var locale: Locale {
        Locale(identifier: languageCode)
    }

    /// Looks up a localized string in the selected language's ``bundle``.
    ///
    /// A small convenience over `NSLocalizedString` that routes through the
    /// chosen bundle rather than the system-selected one.
    func localizedString(_ key: String, comment: String = "") -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    // MARK: - Switching

    /// Switch the app's language.
    ///
    /// - Parameter selection: either ``systemSelection`` to resume following the
    ///   device, or a concrete code from ``supportedLanguages``. Unknown values
    ///   are ignored so the stored state can never become invalid. No-ops (and
    ///   avoids a spurious `@Published` emission) when the selection is unchanged.
    func setLanguage(_ selection: String) {
        guard Self.isValid(selection: selection) else { return }
        guard selection != self.selection else { return }

        self.selection = selection
        defaults.set(selection, forKey: Self.storageKey)
        languageCode = Self.resolve(selection: selection)
    }

    /// Convenience for selecting a specific supported language.
    func setLanguage(_ language: SupportedLanguage) {
        setLanguage(language.code)
    }

    /// Convenience to resume following the system language.
    func followSystem() {
        setLanguage(Self.systemSelection)
    }

    // MARK: - Resolution

    /// Whether `selection` is a value we are willing to persist.
    private static func isValid(selection: String) -> Bool {
        selection == systemSelection || supportedLanguages.contains { $0.code == selection }
    }

    /// Maps a raw selection to a concrete, supported language code.
    private static func resolve(selection: String) -> String {
        if selection == systemSelection {
            return resolveSystemLanguage()
        }
        if supportedLanguages.contains(where: { $0.code == selection }) {
            return selection
        }
        // Defensive: a previously-stored code that is no longer supported.
        return fallbackLanguageCode
    }

    /// Reads the device's ordered language preferences and returns the first that
    /// maps to a supported language, or ``fallbackLanguageCode`` if none do.
    private static func resolveSystemLanguage() -> String {
        for preferred in Locale.preferredLanguages {
            if let match = bestMatch(for: preferred) {
                return match
            }
        }
        return fallbackLanguageCode
    }

    /// Finds the supported language that best fits a system preferred-language
    /// identifier (e.g. `"zh-Hans-CN"`, `"en-US"`).
    ///
    /// Prefers a match on both language and script (so `"zh-Hans-CN"` resolves to
    /// `"zh-Hans"` rather than some other Chinese script), then falls back to a
    /// language-only match.
    private static func bestMatch(for preferred: String) -> String? {
        let preferredLanguage = Locale.Language(identifier: preferred)
        let preferredCode = preferredLanguage.languageCode?.identifier
        let preferredScript = preferredLanguage.script?.identifier

        // First pass: language code + script must both agree.
        for supported in supportedLanguages {
            let language = Locale.Language(identifier: supported.code)
            if language.languageCode?.identifier == preferredCode,
               language.script?.identifier == preferredScript {
                return supported.code
            }
        }

        // Second pass: language code only.
        for supported in supportedLanguages {
            let language = Locale.Language(identifier: supported.code)
            if language.languageCode?.identifier == preferredCode {
                return supported.code
            }
        }

        return nil
    }
}
