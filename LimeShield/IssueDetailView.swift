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
        .brandBackground()
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
                .font(.title2.weight(.heavy))
                .foregroundStyle(Brand.ink)
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

    /// Shown as a chat, billing on the left in white and you on the right in
    /// lime, the same as the "what to say" post.
    private var pushbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "If they push back", count: nil)
            VStack(spacing: 10) {
                ForEach(Array(exchanges.enumerated()), id: \.offset) { index, exchange in
                    bubble("Billing says", exchange.theySay, mine: false)
                    bubble("You say", exchange.youSay, mine: true)
                    if index < exchanges.count - 1 { Spacer().frame(height: 6) }
                }
            }
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
                BrandCard(radius: 20)
            )

            if let note = stateNote {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Pieces

    private func bubble(_ label: String, _ text: String, mine: Bool) -> some View {
        let colors = Brand.buttonColors(for: settings.accentTheme)
        return HStack {
            if mine { Spacer(minLength: 36) }
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.caption2.weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(mine ? colors.text.opacity(0.75) : .secondary)
                Text(text)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(mine ? AnyShapeStyle(colors.text) : AnyShapeStyle(Brand.ink))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(mine ? colors.fill : Brand.card)
                    .shadow(color: Brand.shadow, radius: 10, x: 0, y: 4)
            )
            if !mine { Spacer(minLength: 36) }
        }
        .textSelection(.enabled)
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
