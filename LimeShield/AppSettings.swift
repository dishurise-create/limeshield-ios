import SwiftUI
import Combine

/// User-facing appearance settings. Everything is stored locally with @AppStorage,
/// so preferences survive relaunches without any account or server.
@MainActor
final class AppSettings: ObservableObject {

    // MARK: Theme

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "System"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    // MARK: Accent

    enum AccentTheme: String, CaseIterable, Identifiable {
        case lime, teal, ocean, indigo, forest, sunset, plum
        var id: String { rawValue }
        var label: String {
            switch self {
            case .lime:   return "Lime"
            case .teal:   return "Teal"
            case .ocean:  return "Ocean"
            case .indigo: return "Indigo"
            case .forest: return "Forest"
            case .sunset: return "Sunset"
            case .plum:   return "Plum"
            }
        }
        var color: Color {
            switch self {
            // Sampled from the Lime Shield mark so the app and the icon match.
            case .lime:   return Color(red: 0.44, green: 0.71, blue: 0.06)
            case .teal:   return Color(red: 0.12, green: 0.62, blue: 0.70)
            case .ocean:  return Color(red: 0.09, green: 0.44, blue: 0.79)
            case .indigo: return Color(red: 0.35, green: 0.34, blue: 0.84)
            case .forest: return Color(red: 0.13, green: 0.55, blue: 0.36)
            case .sunset: return Color(red: 0.89, green: 0.44, blue: 0.16)
            case .plum:   return Color(red: 0.63, green: 0.25, blue: 0.55)
            }
        }
    }

    // MARK: Text size

    enum TextScale: String, CaseIterable, Identifiable {
        case small, standard, large, extraLarge
        var id: String { rawValue }
        var label: String {
            switch self {
            case .small:      return "Small"
            case .standard:   return "Standard"
            case .large:      return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
        /// Short form, so four options still fit a segmented control.
        var short: String {
            switch self {
            case .small:      return "S"
            case .standard:   return "M"
            case .large:      return "L"
            case .extraLarge: return "XL"
            }
        }
        var dynamicTypeSize: DynamicTypeSize {
            switch self {
            case .small:      return .small
            case .standard:   return .large
            case .large:      return .xLarge
            case .extraLarge: return .xxxLarge
            }
        }
    }

    // MARK: Stored values

    /// Developer aid: shows what the parser actually extracted from a scan.
    /// Off by default; users never see it unless they turn it on.
    @AppStorage("showDiagnostics") var showDiagnostics = false

    @AppStorage("themeMode") private var themeModeRaw = ThemeMode.system.rawValue
    @AppStorage("accentTheme") private var accentThemeRaw = AccentTheme.lime.rawValue
    @AppStorage("textScale") private var textScaleRaw = TextScale.standard.rawValue

    var themeMode: ThemeMode {
        get { ThemeMode(rawValue: themeModeRaw) ?? .system }
        set { objectWillChange.send(); themeModeRaw = newValue.rawValue }
    }
    var accentTheme: AccentTheme {
        get { AccentTheme(rawValue: accentThemeRaw) ?? .lime }
        set { objectWillChange.send(); accentThemeRaw = newValue.rawValue }
    }
    var textScale: TextScale {
        get { TextScale(rawValue: textScaleRaw) ?? .standard }
        set { objectWillChange.send(); textScaleRaw = newValue.rawValue }
    }

    var accentColor: Color { accentTheme.color }
}
