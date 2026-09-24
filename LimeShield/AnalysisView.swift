import SwiftUI

struct AnalysisView: View {
    @State private var analysis: BillAnalysis
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: AnalysisStore
    @State private var showLetter = false
    @State private var showPaywall = false
    @State private var showEditor = false
    @State private var confirmClearList = false

    init(analysis: BillAnalysis) {
        _analysis = State(initialValue: analysis)
    }

    /// Swift has no key paths into tuples, so grouping uses a small Identifiable type.
    private struct IssueGroup: Identifiable {
        let id: String
        let severity: IssueSeverity
        let issues: [BillIssue]
    }

    private var grouped: [IssueGroup] {
        IssueSeverity.allCases.compactMap { severity in
            let items = analysis.issues.filter { $0.severity == severity }
            guard !items.isEmpty else { return nil }
            let sorted = items.sorted { ($0.estimatedImpact ?? 0) > ($1.estimatedImpact ?? 0) }
            return IssueGroup(id: severity.rawValue, severity: severity, issues: sorted)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                verdict
                if !analysis.issues.isEmpty { todoBlock }
                ForEach(grouped) { group in
                    findingsBlock(group)
                }
                if analysis.canGenerateLetter { letterButton }
                checkBlock
                Text(Disclaimers.short)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(analysis.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLetter) { LetterView(analysis: analysis) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showEditor) {
            EditBillView(bill: analysis.bill) { corrected in apply(corrected) }
        }
    }

    // MARK: Verdict

    private var verdict: some View {
        VStack(spacing: 10) {
            Image(systemName: verdictIcon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(verdictColor)

            Text(verdictTitle)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            if let amount = verdictAmount {
                Text(amount)
                    .font(.title.weight(.bold))
                    .foregroundStyle(settings.accentColor)
                Text("potentially in question")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let sub = verdictSubtitle {
                Text(sub)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var isEOB: Bool { analysis.bill.kind == .insurerEOB }
    private var isMultiple: Bool { analysis.issues.contains { $0.ruleID == "multiple_bills" } }

    private var verdictIcon: String {
        if isEOB { return "exclamationmark.shield.fill" }
        if isMultiple { return "doc.on.doc.fill" }
        if analysis.issues.isEmpty { return "checkmark.seal.fill" }
        return "magnifyingglass.circle.fill"
    }

    private var verdictColor: Color {
        if isEOB || isMultiple { return .orange }
        if analysis.issues.isEmpty { return .green }
        return settings.accentColor
    }

    private var verdictTitle: String {
        if isEOB { return "This is an EOB, not a bill" }
        if isMultiple { return "More than one bill" }
        if analysis.issues.isEmpty { return "Nothing suspicious found" }
        return headlineText
    }

    private var verdictSubtitle: String? {
        if isMultiple { return "Scan each bill on its own." }
        if analysis.issues.isEmpty {
            return "\(analysis.bill.chargeLines.count) charges checked against \(RulesEngine.ruleCount) known problems."
        }
        return nil
    }

    private var verdictAmount: String? {
        guard !isEOB, !isMultiple, !analysis.issues.isEmpty,
              analysis.estimatedImpact > 0 else { return nil }
        return analysis.estimatedImpact.usd
    }

    /// Money-related findings counted separately from rights information.
    private var headlineText: String {
        let questions = analysis.questionableIssues.count
        let rights = analysis.rightsIssues.count
        if questions == 0 {
            return "\(rights) thing\(rights == 1 ? "" : "s") to know"
        }
        let chargeText = "\(questions) charge\(questions == 1 ? "" : "s") to question"
        if rights == 0 { return chargeText }
        return chargeText + " · \(rights) to know"
    }

    // MARK: To-do

    private var todoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Your list", count: analysis.todoIssues.count)

            VStack(spacing: 0) {
                if analysis.todoIssues.isEmpty {
                    Text("Nothing on your list yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }

                ForEach(analysis.todoIssues) { issue in
                    NavigationLink { issueDetail(issue) } label: { todoRow(issue) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                setState(nil, for: issue)
                            } label: {
                                Label("Remove from list", systemImage: "minus.circle")
                            }
                            Button {
                                setState(.done, for: issue)
                            } label: {
                                Label("Mark as done", systemImage: "checkmark.circle")
                            }
                        }
                    Divider().opacity(0.4)
                }

                if !recommended.isEmpty {
                    actionRow(suggestionLabel, "sparkles", settings.accentColor) {
                        addRecommended()
                    }
                }
                if !analysis.todoIssues.isEmpty {
                    Divider().opacity(0.4)
                    actionRow("Clear the list", "trash", .red) { confirmClearList = true }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .confirmationDialog("Clear your list?",
                            isPresented: $confirmClearList,
                            titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                analysis.clearList()
                store.update(analysis)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The findings stay on this scan.")
        }
    }

    private func todoRow(_ issue: BillIssue) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .font(.footnote)
                .foregroundStyle(settings.accentColor)
            Text(issue.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let impact = issue.estimatedImpact, impact > 0 {
                Text(impact.usd)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(settings.accentColor)
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func actionRow(_ title: String, _ icon: String, _ color: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.footnote)
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recommended: [BillIssue] { analysis.recommendedIssues }

    private var suggestionLabel: String {
        analysis.todoIssues.isEmpty
            ? "Add the top \(recommended.count)"
            : "Add \(recommended.count) more"
    }

    private func addRecommended() {
        for issue in recommended { analysis.setState(.todo, for: issue) }
        store.update(analysis)
    }

    // MARK: Findings

    private func findingsBlock(_ group: IssueGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: group.severity.title, count: group.issues.count)
            VStack(spacing: 0) {
                ForEach(Array(group.issues.enumerated()), id: \.element.id) { index, issue in
                    NavigationLink { issueDetail(issue) } label: { issueRow(issue) }
                        .buttonStyle(.plain)
                    if index < group.issues.count - 1 { Divider().opacity(0.4) }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func issueRow(_ issue: BillIssue) -> some View {
        let state = analysis.state(for: issue)
        let faded = state == .done || state == .dismissed
        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(issue.severity.color)
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .strikethrough(state == .done)
                    .fixedSize(horizontal: false, vertical: true)
                if let first = issue.evidence.first {
                    Text(first)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let state {
                    Text(state.label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let impact = issue.estimatedImpact, impact > 0 {
                    Text(impact.usd)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(settings.accentColor)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
        .opacity(faded ? 0.45 : 1)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    // MARK: Letter and scan check

    private var letterButton: some View {
        Button {
            if purchases.canScan { showLetter = true } else { showPaywall = true }
        } label: {
            Label("Generate review letter", systemImage: "envelope")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var checkBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Check the scan", count: nil)
            VStack(spacing: 0) {
                actionRow("Edit what the scan read", "square.and.pencil", settings.accentColor) {
                    showEditor = true
                }
                if settings.showDiagnostics {
                    Divider().opacity(0.4)
                    NavigationLink {
                        DiagnosticsView(bill: analysis.bill)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass").font(.footnote)
                            Text("Scan details").font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(settings.accentColor)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            Text(analysis.editedByUser == true
                 ? "Findings were recalculated from your corrections."
                 : "Wrong amount? Correct it and the findings update.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Actions

    private func issueDetail(_ issue: BillIssue) -> some View {
        IssueDetailView(
            issue: issue,
            state: analysis.state(for: issue),
            onSetState: { newState in setState(newState, for: issue) })
    }

    private func setState(_ state: FindingState?, for issue: BillIssue) {
        analysis.setState(state, for: issue)
        store.update(analysis)
    }

    /// Re-runs every rule against the user's corrections and saves the result.
    private func apply(_ corrected: Bill) {
        analysis.bill = corrected
        analysis.issues = RulesEngine.analyze(corrected)
        analysis.editedByUser = true
        if let provider = corrected.providerName, !provider.isEmpty {
            analysis.title = provider
        }
        store.update(analysis)
    }
}
