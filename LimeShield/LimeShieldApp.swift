import SwiftUI

@main
struct LimeShieldApp: App {
    @StateObject private var store = AnalysisStore()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var settings = AppSettings()
    @StateObject private var account = AccountManager()
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    RootView()
                } else {
                    OnboardingView(done: { hasOnboarded = true })
                }
            }
            .environmentObject(store)
            .environmentObject(purchases)
            .environmentObject(settings)
            .environmentObject(account)
            .tint(settings.accentColor)
            .environment(\.brandTheme, settings.accentTheme)
            .fontDesign(.rounded)
            .preferredColorScheme(settings.themeMode.colorScheme)
            .dynamicTypeSize(settings.textScale.dynamicTypeSize)
            .onAppear { purchases.configure() }
        }
    }
}

/// Public links. The review URL opens the App Store's write-a-review sheet.
enum AppLinks {
    static let appStore = URL(string: "https://apps.apple.com/us/app/lime-shield/id6811397021")!
    static let writeReview = URL(string: "https://apps.apple.com/app/id6811397021?action=write-review")!
    static let shareMessage = "Lime Shield checks a medical bill from a photo and shows what's worth asking billing about. Nothing leaves your phone."
}

enum Disclaimers {
    /// One line. Used anywhere the full text would crowd the screen.
    static let short = "Findings are worth asking about, not proof of error."
    static let privacy = "Processed on this device. Never uploaded."
    static let footer = "Lime Shield highlights items worth reviewing on medical bills. It does not provide legal, medical, or financial advice, and flagged items are not proof of error. Reference prices are rough national ballparks. Your bills are processed entirely on this device and never uploaded."
}

// MARK: - Shared visual language

/// The bright look shared with the App Store screenshots and social posts: a
/// pastel wash, white cards with a soft shadow, dark headlines and a bright
/// marker. Every colour comes from the accent picked in Settings, so choosing
/// Ocean or Sunset recolours the whole app, not just the buttons. Dark mode
/// keeps the same shapes on a deep background.
enum Brand {
    /// Headline text: the accent's darkest tone in light mode, white in dark mode.
    static let ink = BrandInk()
    /// The accent's bright tone. Only ever a fill behind dark text, never text
    /// on white, where it's too light to read.
    static let fill = BrandFill()
    static let card = dynamic(light: .white, dark: .secondarySystemGroupedBackground)
    static let shadow = dynamic(light: UIColor(red: 0.10, green: 0.20, blue: 0.10, alpha: 0.10),
                                dark: .clear)

    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Filled-button colours: the accent's bright tone with its darkest tone on
    /// top, like the posts.
    static func buttonColors(for accent: AppSettings.AccentTheme) -> (fill: Color, text: Color) {
        (accent.bright, accent.deep)
    }
}

private struct BrandThemeKey: EnvironmentKey {
    static let defaultValue: AppSettings.AccentTheme = .lime
}

extension EnvironmentValues {
    /// The accent picked in Settings, set once at the root of the app.
    var brandTheme: AppSettings.AccentTheme {
        get { self[BrandThemeKey.self] }
        set { self[BrandThemeKey.self] = newValue }
    }
}

struct BrandInk: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? .white : environment.brandTheme.deep
    }
}

struct BrandFill: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.brandTheme.bright
    }
}

/// Text that sits on a `BrandFill`: always the accent's darkest tone.
struct BrandOnFill: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.brandTheme.deep
    }
}

/// Full-screen background used behind every screen.
struct BrandBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.brandTheme) private var theme

    var body: some View {
        ZStack {
            if scheme == .dark {
                LinearGradient(colors: [theme.deep.opacity(0.9), Color(red: 0.03, green: 0.04, blue: 0.05)],
                               startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(theme.bright.opacity(0.16))
                    .frame(width: 420, height: 420)
                    .blur(radius: 120)
                    .offset(x: 140, y: -320)
            } else {
                LinearGradient(colors: theme.wash, startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 380, height: 380)
                    .blur(radius: 90)
                    .offset(x: -120, y: -260)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: theme)
    }
}

extension View {
    /// The one card surface used on every screen, so the app reads as a whole.
    func cardSurface(radius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandCard(radius: radius))
    }

    /// Puts the brand background behind a screen. Lists also hide their own grey.
    func brandBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(BrandBackground())
    }
}

/// White rounded card with a soft shadow; plain grouped card in dark mode.
struct BrandCard: View {
    var radius: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Brand.card)
            .shadow(color: Brand.shadow, radius: 14, x: 0, y: 6)
    }
}

/// Two-line headline: dark first line, second line on a bright marker,
/// the same as the screenshots and posts.
struct MarkerHeadline: View {
    let first: String
    let marked: String
    var size: CGFloat = 30

    var body: some View {
        VStack(spacing: 4) {
            Text(first)
                .foregroundStyle(Brand.ink)
            Text(marked)
                .foregroundStyle(BrandOnFill())
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(Capsule().fill(Brand.fill))
        }
        .font(.system(size: size, weight: .heavy, design: .rounded))
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
}

/// The main call-to-action button: full width, big, rounded, filled.
struct BrandButtonStyle: ButtonStyle {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let colors = Brand.buttonColors(for: settings.accentTheme)
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(colors.fill))
            .foregroundStyle(colors.text)
            .shadow(color: colors.fill.opacity(0.35), radius: 10, x: 0, y: 5)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet all-caps heading that sits above a group, with an optional count.
struct SectionLabel: View {
    let text: String
    var count: Int?

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(0.8)
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.caption.weight(.heavy))
            }
        }
        .foregroundStyle(Brand.ink.opacity(0.6))
    }
}

/// Small capsule used for severity labels and the privacy badge.
struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.heavy))
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

extension IssueSeverity {
    var color: Color {
        switch self {
        case .likelyError:    return .red
        case .worthChecking:  return .orange
        case .knowYourRights: return .blue
        }
    }
}
