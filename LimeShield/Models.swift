import Foundation
import Combine
import SwiftUI

// MARK: - Bill model

struct BillLine: Codable, Identifiable, Hashable {
    var id = UUID()
    var raw: String
    var desc: String
    var code: String?
    var date: Date?
    var amount: Double?
    var quantity: Int?
}

struct BillTotals: Codable, Hashable {
    var totalCharges: Double?
    var amountDue: Double?
    var previousBalance: Double?
    var payments: Double?
    var adjustments: Double?
}

/// What kind of document was scanned. An insurer's Explanation of Benefits is not
/// a bill and must not be analysed as one. A provider's itemized statement IS the
/// document Lime Shield tells people to request, so it gets analysed normally.
enum DocumentKind: String, Codable {
    case bill
    case insurerEOB
    case providerItemization
}

struct Bill: Codable, Hashable {
    var lines: [BillLine] = []
    var totals = BillTotals()
    var rawText: String = ""
    var providerName: String?
    var accountNumber: String?
    var statementDate: Date?
    var isLikelyEOB: Bool = false
    /// Set when the scanned pages appear to be two different bills rather than
    /// pages of one bill. Optional so previously-saved scans still decode.
    var multipleBillsDetected: Bool?

    // v8 parse-confidence signals. All optional so older saved scans still decode.

    /// Insurer EOB, provider itemization, or an ordinary bill.
    var documentKind: DocumentKind?
    /// Set when at least one row carried more than one dollar figure, meaning the
    /// page has several money columns (Charges, Adjustments, Balance) and we cannot
    /// be certain which column holds the charge.
    var hasAmbiguousAmountRows: Bool?
    /// Rows recognised as payments, credits or adjustments rather than charges.
    var creditLineCount: Int?
    /// Set once a "total adjustments" row is seen, so per-line adjustments are not
    /// added on top of a total that already includes them.
    var adjustmentsFromTotalRow: Bool?

    var kind: DocumentKind {
        documentKind ?? (isLikelyEOB ? .insurerEOB : .bill)
    }

    var chargeLines: [BillLine] {
        lines.filter { ($0.amount ?? 0) > 0 }
    }
    /// v5.1: itemized = has line detail; a stated charges total also counts as
    /// evidence of itemization (partial OCR parse), see RULES_AUDIT.md pass 5.
    var hasLineDetail: Bool { chargeLines.count >= 3 }

    /// v8: the stated totals can be trusted enough to compare against each other.
    var totalsAreReliable: Bool {
        hasAmbiguousAmountRows != true && multipleBillsDetected != true
    }

    /// v8: line items can be trusted enough to be summed and compared to the total.
    ///
    /// Testing against a real Stanford statement and a real hospital itemization
    /// showed the old math rule accusing honest providers about four times for every
    /// time it was right. Multi-column layouts, credit lines and subtotal rows all
    /// fed it numbers that were never charges. A rule that stays quiet is far better
    /// than one that tells someone their hospital overcharged them when it did not.
    var mathIsReliable: Bool {
        totalsAreReliable && chargeLines.count >= 3
    }
}

// MARK: - Issues

enum IssueSeverity: String, Codable, CaseIterable {
    case likelyError
    case worthChecking
    case knowYourRights

    var title: String {
        switch self {
        case .likelyError:   return "Likely error"
        case .worthChecking: return "Worth checking"
        case .knowYourRights: return "Know your rights"
        }
    }
    var rank: Int {
        switch self {
        case .likelyError: return 0
        case .worthChecking: return 1
        case .knowYourRights: return 2
        }
    }
}

struct BillIssue: Codable, Identifiable, Hashable {
    var id = UUID()
    var ruleID: String
    var title: String
    var detail: String
    var severity: IssueSeverity
    var evidence: [String]
    var estimatedImpact: Double?
    var action: String

    /// Stable across re-analysis, unlike `id`, which is regenerated every run.
    /// Lets a finding keep its to-do state after the user edits the scan.
    var stateKey: String {
        ruleID + "|" + evidence.joined(separator: ";")
    }
}

/// What the user has decided about a finding.
enum FindingState: String, Codable {
    case todo        // on the to-do list, still to be raised
    case done        // asked about and dealt with
    case dismissed   // looked at it, not worth pursuing

    var label: String {
        switch self {
        case .todo:      return "On your list"
        case .done:      return "Done"
        case .dismissed: return "Not an issue"
        }
    }
    var icon: String {
        switch self {
        case .todo:      return "checklist"
        case .done:      return "checkmark.circle.fill"
        case .dismissed: return "minus.circle"
        }
    }
}

// MARK: - Saved analysis

struct BillAnalysis: Codable, Identifiable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var title: String
    var bill: Bill
    var issues: [BillIssue]
    /// True once the user has corrected the scanned data by hand.
    var editedByUser: Bool?
    /// Per-finding to-do state, keyed by BillIssue.stateKey so it survives re-analysis.
    var issueStates: [String: FindingState]?

    // MARK: To-do state

    func state(for issue: BillIssue) -> FindingState? {
        issueStates?[issue.stateKey]
    }

    mutating func setState(_ state: FindingState?, for issue: BillIssue) {
        var states = issueStates ?? [:]
        if let state {
            states[issue.stateKey] = state
        } else {
            states.removeValue(forKey: issue.stateKey)
        }
        issueStates = states.isEmpty ? nil : states
    }

    /// Removes every to-do entry, leaving the findings themselves untouched.
    mutating func clearList() {
        issueStates = nil
    }

    var todoIssues: [BillIssue] {
        issues.filter { state(for: $0) == .todo }
    }

    /// The findings most worth raising first: anything that's arithmetic (those are the
    /// only ones stated as errors), then the biggest-money items worth checking.
    /// Already-tracked and already-dismissed findings are left out, so the suggestion
    /// only ever offers things that aren't on the list yet.
    var recommendedIssues: [BillIssue] {
        let untouched = issues.filter { state(for: $0) == nil }
        let errors = untouched.filter { $0.severity == .likelyError }
        let checks = untouched
            .filter { $0.severity == .worthChecking }
            .sorted { ($0.estimatedImpact ?? 0) > ($1.estimatedImpact ?? 0) }
        return Array((errors + checks).prefix(5))
    }

    /// Findings a letter can actually ask about. "Know your rights" items are context
    /// for the reader, not things to put in front of a billing department, and anything
    /// the user has marked "not an issue" is left out too.
    var actionableIssues: [BillIssue] {
        issues.filter { issue in
            guard issue.severity != .knowYourRights else { return false }
            return state(for: issue) != .dismissed
        }
    }

    /// Findings that might actually cost money, as distinct from rights information.
    var questionableIssues: [BillIssue] {
        issues.filter { $0.severity != .knowYourRights }
    }

    var rightsIssues: [BillIssue] {
        issues.filter { $0.severity == .knowYourRights }
    }

    /// v6.2: only offer a letter when there is something to put in it. An unitemized
    /// bill has its own letter (requesting the itemization), so it counts too.
    var canGenerateLetter: Bool {
        !actionableIssues.isEmpty || issues.contains { $0.ruleID == "not_itemized" }
    }

    /// v6 honesty fix: a math mismatch is usually CAUSED by the line-level findings
    /// (a duplicated $150 charge makes the total $150 off), so adding both double-counts
    /// the same dollars. Report the larger of the two views, never their sum.
    var estimatedImpact: Double {
        let mathRules: Set<String> = ["math", "math_statement"]
        let lineLevel = issues
            .filter { !mathRules.contains($0.ruleID) }
            .compactMap { $0.estimatedImpact }
            .reduce(0, +)
        let mathLevel = issues
            .filter { mathRules.contains($0.ruleID) }
            .compactMap { $0.estimatedImpact }
            .max() ?? 0
        return max(lineLevel, mathLevel)
    }
}

// MARK: - Persistence

@MainActor
final class AnalysisStore: ObservableObject {
    @Published private(set) var analyses: [BillAnalysis] = []

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("analyses.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([BillAnalysis].self, from: data) else { return }
        analyses = decoded
    }

    func add(_ analysis: BillAnalysis) {
        analyses.insert(analysis, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        analyses.remove(atOffsets: offsets)
        save()
    }

    func deleteAll() {
        analyses.removeAll()
        save()
    }

    /// Replaces an analysis in place, keeping its position in the list.
    func update(_ analysis: BillAnalysis) {
        guard let index = analyses.firstIndex(where: { $0.id == analysis.id }) else { return }
        analyses[index] = analysis
        save()
    }

    // MARK: Totals across every scan (v8, used by the home screen)

    /// Every dollar Lime Shield has put a question mark against, all bills combined.
    var totalFlagged: Double {
        analyses.reduce(0) { $0 + $1.estimatedImpact }
    }

    /// Findings still sitting on a to-do list somewhere.
    var openTodoCount: Int {
        analyses.reduce(0) { $0 + $1.todoIssues.count }
    }

    var billCount: Int { analyses.count }

    private func save() {
        guard let data = try? JSONEncoder().encode(analyses) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Formatting helpers

extension Double {
    var usd: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = self.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return f.string(from: NSNumber(value: self)) ?? "$\(self)"
    }
}
