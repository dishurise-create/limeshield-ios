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
            .preferredColorScheme(settings.themeMode.colorScheme)
            .dynamicTypeSize(settings.textScale.dynamicTypeSize)
            .onAppear { purchases.configure() }
        }
    }
}

enum Disclaimers {
    /// One line. Used anywhere the full text would crowd the screen.
    static let short = "Findings are worth asking about, not proof of error."
    static let privacy = "Processed on this device. Never uploaded."
    static let footer = "Lime Shield highlights items worth reviewing on medical bills. It does not provide legal, medical, or financial advice, and flagged items are not proof of error. Reference prices are rough national ballparks. Your bills are processed entirely on this device and never uploaded."
}

// MARK: - Shared visual language

extension View {
    /// The one card surface used on every screen, so the app reads as a whole.
    func cardSurface(radius: CGFloat = 18, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

/// Quiet all-caps heading that sits above a group, with an optional count.
struct SectionLabel: View {
    let text: String
    var count: Int?

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// Small capsule used for severity labels and the privacy badge.
struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.4)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.16)))
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
