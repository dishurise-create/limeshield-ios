import SwiftUI

/// Shared body used by both the Premium tab and the paywall sheet.
struct PremiumBody: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var settings: AppSettings
    var onPurchased: () -> Void = {}
    @State private var isWorking = false

    /// Apple's standard EULA, which this app uses unmodified.
    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://dishurise-create.github.io/limeshield/privacy.html")!

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                benefits
                purchaseArea

                if let error = purchases.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                legal
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 50))
                .foregroundStyle(settings.accentColor)
            Text("Lime Shield Pro")
                .font(.title.weight(.bold))
            Text("One catch pays for years.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var benefits: some View {
        VStack(spacing: 0) {
            benefit("infinity", "Unlimited scans")
            Divider().opacity(0.4)
            benefit("envelope", "Unlimited letters")
            Divider().opacity(0.4)
            benefit("lock.shield", "Still fully on-device")
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var purchaseArea: some View {
        if purchases.isPro {
            Label("Pro is active", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
                .padding(.vertical, 8)
        } else if purchases.isConfigured {
            if purchases.packages.isEmpty {
                if purchases.lastError == nil {
                    ProgressView().task { await purchases.refresh() }
                } else {
                    // Loading failed. Offer a way out instead of spinning forever.
                    Button("Try again") {
                        purchases.lastError = nil
                    }
                    .buttonStyle(.bordered)
                }
            }
            ForEach(purchases.packages) { package in
                Button {
                    Task {
                        isWorking = true
                        await purchases.purchase(package)
                        isWorking = false
                        if purchases.isPro { onPurchased() }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(package.title.isEmpty ? "Subscribe" : package.title)
                            .font(.headline)
                        Text(package.priceWithPeriod).font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking)
            }
            Button("Restore purchases") {
                Task {
                    await purchases.restore()
                    if purchases.isPro { onPurchased() }
                }
            }
            .font(.footnote)
        } else {
            VStack(spacing: 6) {
                Text("Purchases not set up yet").font(.subheadline.weight(.semibold))
                Text("Development builds run fully unlocked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    /// Apple requires the subscription's title, length and price, plus links to the
    /// terms of use and the privacy policy, to be visible inside the app itself.
    private var legal: some View {
        VStack(spacing: 12) {
            Text(renewalText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Link("Terms of Use", destination: Self.termsURL)
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.caption2)
        }
    }

    private var renewalText: String {
        let priced = purchases.packages.first.map {
            "Lime Shield Pro is \($0.priceWithPeriod). "
        } ?? ""
        return priced
            + "Payment is charged to your Apple Account at confirmation of purchase. "
            + "The subscription renews automatically unless it is cancelled at least 24 hours "
            + "before the end of the current period. Manage or cancel anytime in Settings."
    }

    private func benefit(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(settings.accentColor)
                .frame(width: 26)
            Text(title).font(.callout.weight(.medium))
            Spacer()
        }
        .padding(.vertical, 14)
    }
}

/// Premium as a tab.
struct PremiumTabView: View {
    var body: some View {
        NavigationStack {
            PremiumBody()
                .navigationTitle("Premium")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Premium as a sheet, shown when a free-tier limit is hit.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PremiumBody(onPurchased: { dismiss() })
                .navigationTitle("Premium")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
        }
    }
}
