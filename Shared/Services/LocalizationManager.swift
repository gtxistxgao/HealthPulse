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
        SupportedLanguage(code: "zh-Hant", nativeName: "繁體中文"),
        SupportedLanguage(code: "ja", nativeName: "日本語"),
        SupportedLanguage(code: "ko", nativeName: "한국어"),
        SupportedLanguage(code: "es", nativeName: "Español"),
        SupportedLanguage(code: "fr", nativeName: "Français"),
    ]

    /// The stored value meaning "follow the system language".
    static let systemSelection = "system"

    /// The language used when following the system but no preferred language
    /// matches a supported one.
    static let fallbackLanguageCode = "en"

    /// `UserDefaults` key under which the raw selection is persisted.
    private static let storageKey = "HealthPulse.selectedLanguage"

    /// The most recently initialized manager, used to back the global ``L(_:_:)``
    /// function and ``Swift/String/localized(_:)`` helper for code that cannot
    /// observe the object directly (view models, formatters, free functions).
    ///
    /// Held weakly so preview/test instances don't outlive their scope; the
    /// app's `@StateObject` keeps the live instance alive. SwiftUI views should
    /// prefer the instance API (e.g. via `@EnvironmentObject`) so they re-render
    /// when the language changes — the global helpers do not trigger redraws.
    private(set) static weak var current: LocalizationManager?

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
        Self.current = self
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
    /// chosen bundle rather than the system-selected one, so lookups follow the
    /// in-app language selection and stay decoupled from the device language.
    ///
    /// - Parameter comment: ignored at runtime; present so call sites read like
    ///   `NSLocalizedString` and remain discoverable by string-extraction tools.
    func localizedString(_ key: String, comment: String = "") -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Looks up a localized *format* string and substitutes `arguments`,
    /// formatting them with the selected language's ``locale`` (so numbers,
    /// plurals and the like respect the chosen language rather than the device).
    ///
    /// The value stored for `key` is treated as a `String(format:)` template,
    /// e.g. `"%d steps"` / `"%1$@ 的 %2$@"`.
    ///
    /// - Parameters:
    ///   - key: the lookup key whose value is a format template.
    ///   - arguments: the substitution arguments; an empty array returns the
    ///     template unchanged (and avoids treating stray `%` as a specifier).
    func localizedString(_ key: String, arguments: [CVarArg]) -> String {
        let template = bundle.localizedString(forKey: key, value: nil, table: nil)
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: locale, arguments: arguments)
    }

    /// Ergonomic call syntax for the unified lookup, e.g.
    /// `localization("dashboard.title")` or
    /// `localization("steps.count", stepCount)`.
    ///
    /// Routes through ``localizedString(_:arguments:)`` so both the plain and
    /// the parameterized forms share one code path.
    func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
        localizedString(key, arguments: arguments)
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

// MARK: - Global lookup entry point

/// The app's single entry point for localized text.
///
/// Resolves `key` against the language currently selected in
/// ``LocalizationManager`` — i.e. the in-app choice, *not* the device's system
/// language — so runtime language switching and the OS setting stay decoupled.
/// Optional `arguments` are substituted into the looked-up format template using
/// the selected language's locale.
///
/// All UI copy should flow through this function (or its sibling
/// ``Swift/String/localized(_:)``), keeping every string on the same
/// bundle-aware path:
///
/// ```swift
/// Text(L("dashboard.title"))
/// Text(L("steps.count", stepCount))
/// ```
///
/// > Note: this is a plain function read, not an observed value — it does not
/// > itself cause a SwiftUI view to redraw on a language change. Views should
/// > observe ``LocalizationManager`` (e.g. through `@EnvironmentObject`) so a
/// > switch invalidates their body; the lookup inside then returns the new
/// > language's copy. When no manager has been created yet, falls back to
/// > `Bundle.main` so lookups still degrade gracefully.
@MainActor
func L(_ key: String, _ arguments: CVarArg...) -> String {
    localizedLookup(key, arguments: arguments)
}

extension String {
    /// Treats the string as a localization key and resolves it through the
    /// unified ``L(_:_:)`` entry point, optionally substituting `arguments`.
    ///
    /// ```swift
    /// Text("dashboard.title".localized())
    /// Text("steps.count".localized(stepCount))
    /// ```
    @MainActor
    func localized(_ arguments: CVarArg...) -> String {
        localizedLookup(self, arguments: arguments)
    }
}

/// Shared implementation behind ``L(_:_:)`` and ``Swift/String/localized(_:)``.
///
/// Prefers the live ``LocalizationManager`` so lookups honour the in-app
/// selection; if none exists it falls back to `Bundle.main` so text is still
/// rendered (in the system language) instead of crashing or showing the key.
@MainActor
private func localizedLookup(_ key: String, arguments: [CVarArg]) -> String {
    if let manager = LocalizationManager.current {
        return manager.localizedString(key, arguments: arguments)
    }
    let template = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    guard !arguments.isEmpty else { return template }
    return String(format: template, arguments: arguments)
}
