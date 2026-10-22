import Foundation

/// Rules 47 to 50, added in 1.0.1.
///
/// Each one keys on a billing code or a narrow phrase, so it only speaks when the
/// bill gives it something specific. None of them calls anything an error: they
/// are questions to put to billing, and every one stays silent on the clean test
/// bill.
extension RulesEngine {

    static func accuracyRules(_ bill: Bill) -> [BillIssue] {
        var issues: [BillIssue] = []
        issues += repeatedBloodDraw(bill)
        issues += pulseOxWithVisit(bill)
        issues += personalComfortItems(bill)
        issues += sameCodeDifferentPrice(bill)
        return issues
    }

    // MARK: Helpers

    fileprivate static func ev(_ line: BillLine) -> String {
        var parts = [line.desc]
        if let code = line.code { parts.append("(\(code))") }
        if let amount = line.amount { parts.append(amount.usd) }
        return parts.joined(separator: " ")
    }

    fileprivate static func day(_ date: Date?) -> String {
        guard let date else { return "-" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: 47. Blood draw more than once a day

    /// Venipuncture (36415) is normally billed once per encounter, however many
    /// tubes are drawn. Two or more on the same date is worth a question.
    static func repeatedBloodDraw(_ bill: Bill) -> [BillIssue] {
        let draws = bill.chargeLines.filter { $0.code == "36415" }
        let byDay = Dictionary(grouping: draws) { day($0.date) }
        return byDay.values.compactMap { lines in
            let count = lines.reduce(0) { $0 + max($1.quantity ?? 1, 1) }
            guard count >= 2 else { return nil }
            let unit = lines.compactMap(\.amount).min() ?? 0
            let unitPrice = lines.count == 1 ? unit / Double(count) : unit
            return BillIssue(
                ruleID: "blood_draw_repeat",
                title: "Blood draw billed more than once in a day",
                detail: "The blood draw fee (36415) appears \(count) times on the same date. It's usually charged once per visit, no matter how many tubes or tests, unless you were stuck again at a separate time.",
                severity: .worthChecking,
                evidence: lines.map(ev),
                estimatedImpact: unitPrice > 0 ? unitPrice * Double(count - 1) : nil,
                action: "Ask billing whether blood was drawn at separate times that day, and if not, to remove the extra draw fees.")
        }
    }

    // MARK: 48. Pulse oximetry next to a visit

    /// A single pulse-oximetry reading (94760) is part of an office or ER visit
    /// and isn't normally paid on its own. Only fires when a visit code is billed
    /// the same day, so a stand-alone sleep or oxygen study stays quiet.
    static func pulseOxWithVisit(_ bill: Bill) -> [BillIssue] {
        let visitDays = Set(bill.chargeLines
            .filter { ReferenceData.visitCodes.contains($0.code ?? "") }
            .map { day($0.date) })
        guard !visitDays.isEmpty else { return [] }
        let ox = bill.chargeLines.filter { $0.code == "94760" && visitDays.contains(day($0.date)) }
        guard !ox.isEmpty else { return [] }
        return [BillIssue(
            ruleID: "pulse_ox_bundled",
            title: "Oxygen reading billed on top of the visit",
            detail: "A finger pulse-oximetry reading (94760) is billed separately, alongside a visit on the same day. A single reading is normally treated as part of the visit itself.",
            severity: .worthChecking,
            evidence: ox.map(ev),
            estimatedImpact: ox.compactMap(\.amount).reduce(0, +),
            action: "Ask billing whether the oxygen reading is already included in the visit charge.")]
    }

    // MARK: 49. Personal comfort items

    /// Things like lotion, tissues or a TV aren't medical care. Some hospitals
    /// charge for them, some don't, and you can ask what you agreed to. Lines the
    /// routine-supplies rule already caught are left alone so nothing is flagged
    /// twice, and anything carrying a billing code is treated as medical.
    static func personalComfortItems(_ bill: Bill) -> [BillIssue] {
        let items = bill.chargeLines.filter { line in
            // A line with a billing code is a medical service ("tissue pathology",
            // "phone consult"), never a comfort item.
            guard line.code == nil else { return false }
            let d = " " + line.desc.lowercased() + " "
            let isComfort = ReferenceData.comfortItemTerms.contains { d.contains($0) }
            let isSupply = ReferenceData.supplyTerms.contains { d.contains($0) }
            return isComfort && !isSupply
        }
        guard !items.isEmpty else { return [] }
        return [BillIssue(
            ruleID: "comfort_items",
            title: "Personal items on a medical bill",
            detail: "This bill includes personal or comfort items rather than medical care. You can ask whether you were told these would be charged, and to have them removed if you weren't.",
            severity: .worthChecking,
            evidence: items.map(ev),
            estimatedImpact: items.compactMap(\.amount).reduce(0, +),
            action: "Ask billing whether you agreed to pay for these personal items, and to remove any you didn't ask for.")]
    }

    // MARK: 50. Same code, same day, different prices

    /// The duplicate rule catches identical lines. This catches the same code
    /// billed twice on one day at two different prices, which is either two
    /// different services that need explaining or the same one entered twice.
    /// Drug codes (J-codes) are left out: several doses at different strengths
    /// are normal.
    static func sameCodeDifferentPrice(_ bill: Bill) -> [BillIssue] {
        var groups: [String: [BillLine]] = [:]
        for line in bill.chargeLines {
            guard let code = line.code, code.count == 5, code.allSatisfy(\.isNumber),
                  code != "36415", (line.quantity ?? 1) <= 1, line.date != nil else { continue }
            groups[code + "|" + day(line.date), default: []].append(line)
        }
        return groups.values.compactMap { lines in
            let prices = Set(lines.compactMap { $0.amount.map { Int(($0 * 100).rounded()) } })
            guard lines.count >= 2, prices.count >= 2 else { return nil }
            return BillIssue(
                ruleID: "same_code_two_prices",
                title: "Same service billed twice at different prices",
                detail: "Code \(lines[0].code ?? "") is billed \(lines.count) times on the same date, at different prices. That could be two separate services, or the same one entered twice.",
                severity: .worthChecking,
                evidence: lines.map(ev),
                estimatedImpact: lines.compactMap(\.amount).min(),
                action: "Ask billing what each of these charges was for and why the prices differ.")
        }
    }
}
