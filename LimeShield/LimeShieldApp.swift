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

/// The bright look shared with the App Store screenshots and social posts:
/// a mint, lemon and sky wash, white cards with a soft green shadow, dark green
/// headlines and a bright lime marker. Dark mode keeps the same shapes on a
/// deep green background.
enum Brand {
    /// Headline text: dark green in light mode, white in dark mode.
    static let ink = dynamic(light: UIColor(red: 0.08, green: 0.21, blue: 0.10, alpha: 1),
                             dark: .white)
    /// Bright lime from the posts. Used as a fill behind ink text, never as text
    /// on white, where it's too light to read.
    static let limeFill = Color(red: 0.49, green: 0.83, blue: 0.13)
    static let card = dynamic(light: .white, dark: .secondarySystemGroupedBackground)
    static let shadow = dynamic(light: UIColor(red: 0.08, green: 0.25, blue: 0.08, alpha: 0.10),
                                dark: .clear)

    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Filled-button colours for an accent. Lime gets the bright fill with dark
    /// text, like the posts; the other accents keep white text.
    static func buttonColors(for accent: AppSettings.AccentTheme) -> (fill: Color, text: Color) {
        accent == .lime ? (limeFill, Color(red: 0.08, green: 0.21, blue: 0.10)) : (accent.color, .white)
    }
}

/// Full-screen background used behind every screen.
struct BrandBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if scheme == .dark {
                LinearGradient(colors: [Color(red: 0.05, green: 0.09, blue: 0.05),
                                        Color(red: 0.03, green: 0.04, blue: 0.05)],
                               startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(Brand.limeFill.opacity(0.16))
                    .frame(width: 420, height: 420)
                    .blur(radius: 120)
                    .offset(x: 140, y: -320)
            } else {
                LinearGradient(colors: [Color(red: 0.87, green: 0.97, blue: 0.78),
                                        Color(red: 1.00, green: 0.96, blue: 0.75),
                                        Color(red: 0.85, green: 0.93, blue: 1.00)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 380, height: 380)
                    .blur(radius: 90)
                    .offset(x: -120, y: -260)
            }
        }
        .ignoresSafeArea()
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

/// Two-line headline: dark green first line, second line on a lime marker,
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
                .foregroundStyle(Color(red: 0.08, green: 0.21, blue: 0.10))
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(Capsule().fill(Brand.limeFill))
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
