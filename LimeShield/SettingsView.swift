import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var account: AccountManager
    @EnvironmentObject private var store: AnalysisStore

    @State private var showPaywall = false
    @State private var confirmClearHistory = false

    var body: some View {
        List {
            appearanceSection
            accentSection
            accountSection
            subscriptionSection
            dataSection
            advancedSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: Binding(
                get: { settings.themeMode },
                set: { settings.themeMode = $0 })) {
                    ForEach(AppSettings.ThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

            Picker("Text size", selection: Binding(
                get: { settings.textScale },
                set: { settings.textScale = $0 })) {
                    ForEach(AppSettings.TextScale.allCases) { scale in
                        Text(scale.short).tag(scale)
                    }
                }
                .pickerStyle(.segmented)
        }
    }

    private var accentSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                      spacing: 14) {
                ForEach(AppSettings.AccentTheme.allCases) { theme in
                    Button {
                        settings.accentTheme = theme
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(theme.color).frame(width: 36, height: 36)
                                if settings.accentTheme == theme {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(theme.label)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Account

    private var accountSection: some View {
        Section {
            if account.isSignedIn {
                HStack {
                    Label(account.displayName, systemImage: "person.crop.circle.fill")
                    Spacer()
                    Button("Sign out") { account.signOut() }
                        .font(.footnote)
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    account.handle(result)
                }
                .signInWithAppleButtonStyle(
                    settings.themeMode == .dark ? .white : .black)
                .frame(height: 44)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if let error = account.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Optional. Only used to recognise your subscription on another device.")
        }
    }

    // MARK: Subscription

    private var subscriptionSection: some View {
        Section("Subscription") {
            if purchases.isPro {
                Label("Pro is active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Get Lime Shield Pro") { showPaywall = true }
            }
            Button("Restore purchases") { Task { await purchases.restore() } }
        }
    }

    // MARK: Advanced

    private var advancedSection: some View {
        Section {
            Toggle("Show scan details", isOn: $settings.showDiagnostics)
        } header: {
            Text("Advanced")
        } footer: {
            Text("Adds a screen showing exactly what was read from each bill.")
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                confirmClearHistory = true
            } label: {
                Label("Delete all past scans", systemImage: "trash")
            }
            .confirmationDialog("Delete all past scans?",
                                isPresented: $confirmClearHistory,
                                titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { store.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        } header: {
            Text("Your data")
        } footer: {
            Text("Scans live only in this app on this device.")
        }
    }
}
