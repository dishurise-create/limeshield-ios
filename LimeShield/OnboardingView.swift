import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    var done: () -> Void
    @State private var page = 0

    private let pages: [(icon: String, title: String, body: String)] = [
        ("doc.text.magnifyingglass",
         "Most bills have errors",
         "Duplicate charges, inflated prices, math that doesn't add up."),
        ("lock.shield.fill",
         "Private by design",
         "Read and checked on this phone. No uploads, no account, no server."),
        ("envelope",
         "Then push back",
         "Lime Shield writes the letter asking billing to explain."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        Image(systemName: pages[index].icon)
                            .font(.system(size: 60))
                            .foregroundStyle(settings.accentColor)
                        Text(pages[index].title)
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(pages[index].body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 36)
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 { withAnimation { page += 1 } }
                else { done() }
            } label: {
                Text(page < pages.count - 1 ? "Continue" : "Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
    }
}
