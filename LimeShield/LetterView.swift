import SwiftUI

struct LetterView: View {
    let analysis: BillAnalysis
    @AppStorage("patientName") private var patientName = ""
    @State private var letterText = ""
    @Environment(\.dismiss) private var dismiss

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
        }
    }

    private func regenerate() {
        letterText = DisputeLetterGenerator.letter(for: analysis, patientName: patientName)
    }
}
