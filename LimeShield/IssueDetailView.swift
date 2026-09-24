import SwiftUI
import UIKit

struct IssueDetailView: View {
    let issue: BillIssue
    let state: FindingState?
    let onSetState: (FindingState?) -> Void

    @EnvironmentObject private var settings: AppSettings
    @State private var copied = false

    private var exchanges: [Pushback.Exchange] {
        Pushback.exchanges(for: issue.ruleID)
    }

    /// A single sentence to read out on the phone or paste into a portal.
    private var question: String {
        var parts: [String] = []
        if let first = issue.evidence.first {
            parts.append("I'm looking at a charge on my bill: \(first).")
        }
        parts.append(issue.action)
        return parts.joined(separator: " ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerCard
                if !issue.evidence.isEmpty { evidenceCard }
                askCard
                if !exchanges.isEmpty { pushbackCard }
                trackCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Finding")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Cards

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Pill(text: issue.severity.title, color: issue.severity.color)
                if let impact = issue.estimatedImpact, impact > 0 {
                    Pill(text: impact.usd, color: settings.accentColor)
                }
            }
            Text(issue.title)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(issue.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface(padding: 18)
    }

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "From your bill", count: nil)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(issue.evidence, id: \.self) { line in
                    Text(line)
                        .font(.caption.monospaced())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .cardSurface()
        }
    }

    private var askCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "What to ask", count: nil)
            VStack(alignment: .leading, spacing: 14) {
                Text(issue.action)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    UIPasteboard.general.string = question
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy the question",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(settings.accentColor)
            }
            .cardSurface()
        }
    }

    private var pushbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "If they push back", count: nil)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(exchanges.enumerated()), id: \.offset) { index, exchange in
                    VStack(alignment: .leading, spacing: 10) {
                        reply("They may say", exchange.theySay, .secondary)
                        reply("You can say", exchange.youSay, settings.accentColor)
                    }
                    .padding(.vertical, 12)
                    if index < exchanges.count - 1 { Divider().opacity(0.4) }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private var trackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Track this", count: nil)
            VStack(spacing: 0) {
                if state == .todo {
                    row("Remove from my list", "minus.circle", .red) { onSetState(nil) }
                } else {
                    row("Add to my list", "checklist", settings.accentColor) { onSetState(.todo) }
                }
                Divider().opacity(0.4)
                row(state == .done ? "Mark as still to do" : "Mark as done",
                    state == .done ? "arrow.uturn.backward" : "checkmark.circle",
                    settings.accentColor) {
                    onSetState(state == .done ? nil : .done)
                }
                Divider().opacity(0.4)
                row(state == .dismissed ? "Put this back" : "Not an issue",
                    state == .dismissed ? "arrow.uturn.backward" : "minus.circle",
                    state == .dismissed ? settings.accentColor : .red) {
                    onSetState(state == .dismissed ? nil : .dismissed)
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            if let note = stateNote {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Pieces

    private func reply(_ label: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.4)
                .foregroundStyle(color)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ title: String, _ icon: String, _ color: Color,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.footnote)
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var stateNote: String? {
        switch state {
        case .todo:      return "On your list."
        case .done:      return "Marked done. It stays on the scan."
        case .dismissed: return "Left out of the review letter."
        case .none:      return nil
        }
    }
}
