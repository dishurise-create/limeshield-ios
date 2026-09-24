import Foundation

/// Lime Shield rules engine v5.1, on-device, no network.
///
/// Drafted, then audited five times for loopholes and improvements, and validated
/// against six synthetic bills (including a clean-bill zero-false-positive check).
/// See RULES_AUDIT.md at the repo root for the full audit log. Key design rules:
///  * Severity tiers never overclaim: only pure arithmetic is a "likely error";
///    everything else is phrased as a question to ask, or as rights information.
///  * Direction-aware math: a parsed line-sum below the stated total never flags
///    (OCR may have missed lines); only an EXCESS is a signal.
///  * Every field is optional; rules skip missing data instead of guessing.
enum RulesEngine {

    static func analyze(_ bill: Bill) -> [BillIssue] {
        // Pass-4 fix, refined in v8: only an INSURER's Explanation of Benefits stops
        // the analysis. A provider's itemized statement also says "this is not a bill",
        // but it is the document Lime Shield asks people to request, and it is where
        // billing errors are easiest to see, so it gets read like any other bill.
        if bill.kind == .insurerEOB {
            return [BillIssue(
                ruleID: "eob",
                title: "This looks like an EOB, not a bill",
                detail: "This document appears to be an Explanation of Benefits from an insurer. It usually says \"THIS IS NOT A BILL\". You should not pay from this document. Wait for the provider's actual bill and compare the two.",
                severity: .knowYourRights,
                evidence: [],
                estimatedImpact: nil,
                action: "Don't pay from this document. Compare it against the provider's bill when it arrives.")]
        }

        // v6.1: two different "total charges" figures means two different bills were
        // scanned together. Their line items would sum into a false math finding, so
        // stop and tell the user rather than reporting confident nonsense.
        if bill.multipleBillsDetected == true {
            return [BillIssue(
                ruleID: "multiple_bills",
                title: "This looks like more than one bill",
                detail: "These pages contain more than one set of total charges, which usually means two separate bills were scanned together. Lime Shield can't check the math across different bills, so scan them one at a time for accurate results.",
                severity: .knowYourRights,
                evidence: [],
                estimatedImpact: nil,
                action: "Scan each bill separately. Multiple photos should only be used for multiple pages of the same bill.")]
        }

        var issues: [BillIssue] = []
        if bill.kind == .providerItemization {
            issues.append(BillIssue(
                ruleID: "itemization",
                title: "This is an itemized statement, not a bill",
                detail: "This document lists what was billed for your care rather than asking for payment, so the balance may already be settled by insurance. Check the account balance before paying anything. Lime Shield has still checked the charges below, because an itemized statement is where billing errors are easiest to spot.",
                severity: .knowYourRights,
                evidence: [],
                estimatedImpact: nil,
                action: "Compare this itemization against the bill you were sent, and against your insurer's Explanation of Benefits."))
        }
        issues += duplicateCharges(bill)
        issues += mathMismatch(bill)
        issues += notItemized(bill)
        issues += vagueCharges(bill)
        issues += priceOutliers(bill)
        issues += highIntensityCodes(bill)
        issues += unbundling(bill)
        issues += dateAnomalies(bill)
        issues += quantityAnomalies(bill)
        issues += suppliesBilledSeparately(bill)
        issues += surpriseBilling(bill)
        issues += extendedRules(bill)   // rules 14-30, see RulesEngineExtended.swift
        issues += furtherRules(bill)    // rules 31-45, see RulesEngineMore.swift
        return postProcess(issues)
    }

    /// How many distinct checks a bill is put through. Shown in the results header.
    static let ruleCount = 46

    // MARK: Post-processing (pass 5: merge, rank, cap)

    private static func postProcess(_ issues: [BillIssue]) -> [BillIssue] {
        var seen = Set<String>()
        var merged: [BillIssue] = []
        // v8: a credit balance and "payments exceed charges" are the same fact seen
        // from two sides. Saying it twice makes one refund look like two problems.
        let hasCreditBalance = issues.contains { $0.ruleID == "credit_balance" }
        for issue in issues {
            if hasCreditBalance && issue.ruleID == "payments_exceed_charges" { continue }
            let key = issue.ruleID + "|" + issue.evidence.joined(separator: ";")
            if seen.insert(key).inserted { merged.append(issue) }
        }
        merged.sort {
            if $0.severity.rank != $1.severity.rank { return $0.severity.rank < $1.severity.rank }
            return ($0.estimatedImpact ?? 0) > ($1.estimatedImpact ?? 0)
        }
        return Array(merged.prefix(ReferenceData.maxIssuesShown))
    }

    // MARK: Helpers

    /// Pass-1 fix: normalized matching key resilient to OCR noise.
    private static func normalizedDesc(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(24))
    }

    private static func dayKey(_ date: Date?) -> String {
        guard let date else { return "-" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func evidence(_ line: BillLine) -> String {
        var parts: [String] = [line.desc]
        if let code = line.code { parts.append("(\(code))") }
        if let amount = line.amount { parts.append(amount.usd) }
        return parts.joined(separator: " ")
    }

    // MARK: Rules

    private static func duplicateCharges(_ bill: Bill) -> [BillIssue] {
        var groups: [String: [BillLine]] = [:]
        for line in bill.chargeLines {
            // Pass-1 fix: lines disclosing quantity > 1 are excluded.
            if let qty = line.quantity, qty > 1 { continue }
            guard let amount = line.amount else { continue }
            let key = (line.code ?? normalizedDesc(line.desc)) + "|" + dayKey(line.date)
                + "|" + String(Int((amount * 100).rounded()))
            groups[key, default: []].append(line)
        }
        return groups.values.filter { $0.count >= 2 }.map { lines in
            let amount = lines[0].amount ?? 0
            return BillIssue(
                ruleID: "duplicate",
                title: "Possible duplicate charge",
                detail: "\"\(lines[0].desc)\" appears \(lines.count) times with the same date and amount. Repeat services can be legitimate, but identical entries are one of the most common billing errors, so ask the provider to confirm each was actually performed.",
                severity: .worthChecking,
                evidence: lines.map(evidence),
                estimatedImpact: amount * Double(lines.count - 1),
                action: "Ask billing to verify that each instance of this charge corresponds to a distinct service in your medical record.")
        }
    }

    private static func mathMismatch(_ bill: Bill) -> [BillIssue] {
        var issues: [BillIssue] = []
        let lines = bill.chargeLines
        // Pass-3 fix: direction-aware, so only an excess over the stated total flags.
        // v8: and only when the parse itself is trustworthy. This is the rule that was
        // accusing honest providers on multi-column statements.
        if let total = bill.totals.totalCharges, bill.mathIsReliable {
            let sum = lines.compactMap { $0.amount }.reduce(0, +)
            let tolerance = max(ReferenceData.mathTolerance, total * 0.005)
            if sum > total + tolerance {
                issues.append(BillIssue(
                    ruleID: "math",
                    title: "Line items add up to more than the stated total",
                    detail: "The individual charges sum to \(sum.usd), but the bill states total charges of \(total.usd), a difference of \((sum - total).usd). One of these figures is wrong, so request a corrected statement.",
                    severity: .likelyError,
                    evidence: ["Sum of line items: \(sum.usd)", "Stated total charges: \(total.usd)"],
                    estimatedImpact: sum - total,
                    action: "Ask billing for a corrected, itemized statement that reconciles the line items with the total."))
            }
        }
        // Full statement equation only when ALL five fields parsed (pass-1 fix) and
        // the totals themselves are trustworthy (v8).
        if bill.totalsAreReliable,
           let prev = bill.totals.previousBalance,
           let charges = bill.totals.totalCharges,
           let pays = bill.totals.payments,
           let adj = bill.totals.adjustments,
           let due = bill.totals.amountDue {
            let expected = prev + charges - pays - adj
            if abs(expected - due) > ReferenceData.mathTolerance {
                issues.append(BillIssue(
                    ruleID: "math_statement",
                    title: "Statement balance doesn't add up",
                    detail: "Previous balance plus new charges, minus payments and adjustments, comes to \(expected.usd), but the bill asks for \(due.usd).",
                    severity: .likelyError,
                    evidence: ["Expected balance: \(expected.usd)", "Stated amount due: \(due.usd)"],
                    estimatedImpact: abs(expected - due),
                    action: "Ask billing to walk you through how the amount due was calculated."))
            }
        }
        return issues
    }

    private static func notItemized(_ bill: Bill) -> [BillIssue] {
        // v5.1 fix (caught by validation suite): only flag when line detail AND a
        // stated charges total are both absent. See RULES_AUDIT.md pass 5.
        guard !bill.hasLineDetail,
              bill.totals.totalCharges == nil,
              (bill.totals.amountDue ?? 0) > ReferenceData.notItemizedMinDue else { return [] }
        return [BillIssue(
            ruleID: "not_itemized",
            title: "This bill isn't itemized",
            detail: "This looks like a summary bill with no line-by-line detail. You are entitled to a fully itemized bill showing every charge and billing code. Most billing errors are only visible on the itemized version, so always get it before paying a large balance.",
            severity: .knowYourRights,
            evidence: [],
            estimatedImpact: nil,
            action: "Send the provider an itemized-bill request (Lime Shield can generate the letter), then rescan the itemized bill.")]
    }

    private static func vagueCharges(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            guard let amount = line.amount, amount >= ReferenceData.vagueThreshold else { return nil }
            let d = line.desc.lowercased()
            guard ReferenceData.vagueTerms.contains(where: { d.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "vague",
                title: "Large vague charge",
                detail: "\"\(line.desc)\" for \(amount.usd) doesn't say what you're actually being charged for. Vague lump sums are where errors and padding hide, so ask for a breakdown.",
                severity: .worthChecking,
                evidence: [evidence(line)],
                estimatedImpact: nil,
                action: "Ask billing to break this charge into specific items with billing codes.")
        }
    }

    private static func priceOutliers(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            guard let code = line.code,
                  let benchmark = ReferenceData.benchmarks[code],
                  let amount = line.amount,
                  amount >= benchmark * ReferenceData.outlierMultiplier else { return nil }
            return BillIssue(
                ruleID: "outlier",
                title: "Billed far above typical rates",
                detail: "\"\(line.desc)\" is billed at \(amount.usd). A rough national reference for code \(code) is around \(benchmark.usd), so this charge is more than \(Int(amount / benchmark))x that. Billed charges are routinely negotiable, especially for self-pay patients.",
                severity: .worthChecking,
                evidence: [evidence(line)],
                estimatedImpact: amount - benchmark,
                action: "Ask for the cash/self-pay price, cite typical rates, and request a reduction or the hospital's financial assistance policy.")
        }
    }

    private static func highIntensityCodes(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            guard let code = line.code, ReferenceData.highIntensityCodes.contains(code) else { return nil }
            return BillIssue(
                ruleID: "high_intensity",
                title: "Highest-intensity billing code used",
                detail: "Code \(code) is the highest-severity level for this type of service. That can be completely appropriate, but these codes are also the most commonly up-coded. You can ask for the documentation that supports this level.",
                severity: .knowYourRights,
                evidence: [evidence(line)],
                estimatedImpact: nil,
                action: "Ask the provider what documentation supports billing at this level rather than a lower one.")
        }
    }

    private static func unbundling(_ bill: Bill) -> [BillIssue] {
        var byDate: [String: Set<String>] = [:]
        var lineFor: [String: BillLine] = [:]
        for line in bill.chargeLines {
            guard let code = line.code else { continue }
            let day = dayKey(line.date)
            byDate[day, default: []].insert(code)
            lineFor[day + code] = line
        }
        var issues: [BillIssue] = []
        for (day, codes) in byDate {
            for pair in ReferenceData.bundlePairs {
                let overlap = codes.intersection(pair.components)
                guard codes.contains(pair.panel), !overlap.isEmpty else { continue }
                let ev = ([pair.panel] + overlap.sorted()).compactMap { lineFor[day + $0] }.map(evidence)
                issues.append(BillIssue(
                    ruleID: "unbundle",
                    title: "Tests that are usually billed as one panel",
                    detail: "This bill charges for a \(pair.name) AND separately for tests that are normally included in it. Billing components separately on top of the panel ('unbundling') can inflate the bill, so verify these were distinct tests.",
                    severity: .worthChecking,
                    evidence: ev,
                    estimatedImpact: nil,
                    action: "Ask billing to confirm the separate tests were not part of the panel already billed."))
            }
        }
        return issues
    }

    private static func dateAnomalies(_ bill: Bill) -> [BillIssue] {
        guard let statementDate = bill.statementDate else { return [] }
        // Pass-3 fix: require > 1 day gap to survive OCR digit confusion.
        let threshold = statementDate.addingTimeInterval(60 * 60 * 24)
        return bill.chargeLines.compactMap { line in
            guard let date = line.date, date > threshold else { return nil }
            return BillIssue(
                ruleID: "date_anomaly",
                title: "Service dated after the statement",
                detail: "\"\(line.desc)\" is dated after this statement was issued, and a service can't be billed before it happens. This may be a data-entry error.",
                severity: .worthChecking,
                evidence: [evidence(line)],
                estimatedImpact: nil,
                action: "Ask billing to verify the date of service for this charge.")
        }
    }

    private static func quantityAnomalies(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            guard let qty = line.quantity, qty > 31 else { return nil }
            let d = line.desc.lowercased()
            // Pass-4 fix: only day-based items (anesthesia units etc. are legit).
            guard ReferenceData.dayBasedTerms.contains(where: { d.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "quantity",
                title: "Impossible quantity for a daily charge",
                detail: "\"\(line.desc)\" is billed \(qty) times, more than the days in a month for what looks like a daily charge.",
                severity: .worthChecking,
                evidence: [evidence(line)],
                estimatedImpact: nil,
                action: "Ask billing to confirm the number of days you were actually admitted.")
        }
    }

    private static func suppliesBilledSeparately(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            let d = line.desc.lowercased()
            guard ReferenceData.supplyTerms.contains(where: { d.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "supplies",
                title: "Basic supplies billed separately",
                detail: "\"\(line.desc)\". Routine supplies like this are usually included in the room or procedure fee, not billed on top of it.",
                severity: .worthChecking,
                evidence: [evidence(line)],
                estimatedImpact: line.amount,
                action: "Ask billing why this item is charged separately from the facility fee.")
        }
    }

    private static func surpriseBilling(_ bill: Bill) -> [BillIssue] {
        let low = " " + bill.rawText.lowercased() + " "
        let outOfNetwork = ReferenceData.surpriseMarkers.contains { low.contains($0) }
        let emergency = ReferenceData.erMarkers.contains { low.contains($0) }
        guard outOfNetwork && emergency else { return [] }
        return [BillIssue(
            ruleID: "surprise_billing",
            title: "Possible surprise bill, and you have federal protections",
            detail: "This looks like an out-of-network charge for emergency care. Under the federal No Surprises Act, you generally can't be balance-billed beyond in-network cost sharing for emergency services.",
            severity: .knowYourRights,
            evidence: [],
            estimatedImpact: nil,
            action: "Tell the provider you believe this bill is covered by the No Surprises Act and ask them to rebill at the in-network rate.")]
    }
}
