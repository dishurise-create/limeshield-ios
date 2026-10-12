import SwiftUI
import StoreKit

struct LetterView: View {
    let analysis: BillAnalysis
    @AppStorage("patientName") private var patientName = ""
    @State private var letterText = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    /// App version that last asked for a rating, so we ask at most once per version.
    @AppStorage("reviewPromptVersion") private var reviewPromptVersion = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Your name (appears in the letter)", text: $patientName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: patientName) { _, _ in regenerate() }

                TextEditor(text: $letterText)
                    .font(.callout.monospaced())
                    .padding(.horizontal)
            }
            .navigationTitle((analysis.letterKind ?? .review).screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: letterText) { Image(systemName: "square.and.arrow.up") }
                }
            }
            .onAppear { regenerate() }
            .onDisappear(perform: askForReviewOnce)
        }
    }

    /// Finishing a letter for a real bill is when the app has just been useful,
    /// so that's when to ask. Never on the sample bill. iOS also limits how
    /// often the prompt can appear.
    private func askForReviewOnce() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !analysis.isSample, reviewPromptVersion != version else { return }
        reviewPromptVersion = version
        Task {
            try? await Task.sleep(for: .seconds(1))
            requestReview()
        }
    }

    private func regenerate() {
        letterText = DisputeLetterGenerator.letter(for: analysis, patientName: patientName)
    }
}
