import Foundation

/// Stable language codes are persisted; their display names come from each language's own table.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en", russian = "ru", german = "de", french = "fr", spanish = "es"
    var id: String { rawValue }
    var name: String {
        let key: String
        switch self {
        case .english: key = "English"
        case .russian: key = "Russian"
        case .german: key = "German"
        case .french: key = "French"
        case .spanish: key = "Spanish"
        }
        return L10n.string(key, language: self)
    }
}

/// App-owned text changes immediately. Converter diagnostics remain English for support reports.
enum L10n {
    static var language: AppLanguage {
        get { UserDefaults.standard.string(forKey: "appLanguage").flatMap(AppLanguage.init(rawValue:)) ?? .english }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
            // This is the app's preferences domain, not the Mac's global language setting.
            UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
        }
    }

    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        string(key, language: language, arguments: arguments)
    }

    static func string(_ key: String, language: AppLanguage, arguments: [CVarArg] = []) -> String {
        let value = resourceBundle(for: language)?.localizedString(forKey: key, value: key, table: nil) ?? key
        return arguments.isEmpty ? value : String(format: value, locale: Locale(identifier: language.rawValue), arguments: arguments)
    }

    static func resourceBundle(for language: AppLanguage) -> Bundle? {
        // Release apps copy lproj folders into their own resources; SwiftPM owns them in development.
        let resources = Bundle.main.bundleIdentifier == "com.stpashik.yuzu-converter" ? Bundle.main : Bundle.module
        guard let path = resources.path(forResource: language.rawValue, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}
