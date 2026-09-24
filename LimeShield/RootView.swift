import SwiftUI

struct RootView: View {
    @State private var tab: Tab = .scan

    enum Tab: Hashable { case scan, history, learn, premium }

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Scan", systemImage: "doc.text.viewfinder") }
                .tag(Tab.scan)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            LearnView()
                .tabItem { Label("Learn", systemImage: "book") }
                .tag(Tab.learn)

            PremiumTabView()
                .tabItem { Label("Premium", systemImage: "sparkles") }
                .tag(Tab.premium)
        }
    }
}
