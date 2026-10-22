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
        /// Bright version, used as a fill behind `deep` text (markers, buttons).
        var bright: Color {
            switch self {
            case .lime:   return Color(red: 0.49, green: 0.83, blue: 0.13)
            case .teal:   return Color(red: 0.30, green: 0.82, blue: 0.85)
            case .ocean:  return Color(red: 0.40, green: 0.68, blue: 1.00)
            case .indigo: return Color(red: 0.58, green: 0.58, blue: 1.00)
            case .forest: return Color(red: 0.33, green: 0.80, blue: 0.52)
            case .sunset: return Color(red: 1.00, green: 0.64, blue: 0.32)
            case .plum:   return Color(red: 0.88, green: 0.50, blue: 0.82)
            }
        }
        /// Very dark version, used for headlines and for text on `bright`.
        var deep: Color {
            switch self {
            case .lime:   return Color(red: 0.08, green: 0.21, blue: 0.10)
            case .teal:   return Color(red: 0.03, green: 0.20, blue: 0.24)
            case .ocean:  return Color(red: 0.05, green: 0.15, blue: 0.33)
            case .indigo: return Color(red: 0.13, green: 0.11, blue: 0.35)
            case .forest: return Color(red: 0.05, green: 0.22, blue: 0.13)
            case .sunset: return Color(red: 0.33, green: 0.13, blue: 0.03)
            case .plum:   return Color(red: 0.30, green: 0.08, blue: 0.26)
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
