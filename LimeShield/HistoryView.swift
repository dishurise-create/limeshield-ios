import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AnalysisStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            Group {
                if store.analyses.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.analyses) { analysis in
                            NavigationLink(value: analysis.id) {
                                row(analysis)
                            }
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("Past scans")
            .toolbar {
                if !store.analyses.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let analysis = store.analyses.first(where: { $0.id == id }) {
                    AnalysisView(analysis: analysis)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No scans yet").font(.title3.bold())
            Text("Bills you scan will be listed here, stored only on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func row(_ analysis: BillAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(analysis.title).font(.headline)
            HStack(spacing: 6) {
                Text(analysis.createdAt, style: .date)
                Text("·")
                if analysis.issues.isEmpty {
                    Text("No findings")
                } else {
                    Text("\(analysis.issues.count) finding\(analysis.issues.count == 1 ? "" : "s")")
                        .foregroundStyle(.orange)
                }
                if analysis.estimatedImpact > 0 {
                    Text("· up to \(analysis.estimatedImpact.usd)")
                        .foregroundStyle(settings.accentColor)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let due = analysis.bill.totals.amountDue, due > 0 {
                Text("Amount due \(due.usd)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
