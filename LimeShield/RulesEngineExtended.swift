import Foundation

/// Rules 14 to 30, added in v7.
///
/// Same discipline as the original thirteen (see RULES_AUDIT.md): only arithmetic is
/// ever called an error, anything judgement-based is phrased as a question to ask, and
/// every rule skips quietly when the data it needs wasn't parsed. Each one was checked
/// against the clean test bill to confirm it stays silent on a correct statement.
extension RulesEngine {

    static func extendedRules(_ bill: Bill) -> [BillIssue] {
        var issues: [BillIssue] = []
        issues += amountDueExceedsCharges(bill)
        issues += creditBalance(bill)
        issues += paymentsExceedCharges(bill)
        issues += repeatedAcrossDates(bill)
        issues += twoVisitsSameDay(bill)
        issues += drugMarkup(bill)
        issues += assistantSurgeon(bill)
        issues += preventiveWithCharge(bill)
        issues += vaccineCharge(bill)
        issues += afterHoursFee(bill)
        issues += missedAppointmentFee(bill)
        issues += interestOrLateFee(bill)
        issues += observationStatus(bill)
        issues += timelyFiling(bill)
        issues += collectionsPressure(bill)
        issues += financialAssistance(bill)
        issues += noInsuranceApplied(bill)
        return issues
    }

    // MARK: Helpers (file-local copies so this file stands alone)

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

    fileprivate static func norm(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(24))
    }

    fileprivate static func textContains(_ bill: Bill, _ terms: [String]) -> Bool {
        let lowered = bill.rawText.lowercased()
        return terms.contains { lowered.contains($0) }
    }

    // MARK: 14-16. Arithmetic (likely error)

    /// 14. Asking for more than was charged, with no prior balance to explain it.
    static func amountDueExceedsCharges(_ bill: Bill) -> [BillIssue] {
        guard bill.totalsAreReliable,
              let due = bill.totals.amountDue,
              let charges = bill.totals.totalCharges,
              bill.totals.previousBalance == nil,
              due > charges + ReferenceData.mathTolerance else { return [] }
        return [BillIssue(
            ruleID: "due_exceeds_charges",
            title: "Amount due is more than the total charges",
            detail: "This bill asks for \(due.usd) but only lists \(charges.usd) in charges, and shows no previous balance to account for the difference of \((due - charges).usd).",
            severity: .likelyError,
            evidence: ["Total charges: \(charges.usd)", "Amount due: \(due.usd)"],
            estimatedImpact: due - charges,
            action: "Ask billing to explain what the amount above the listed charges is for.")]
    }

    /// 15. A negative balance means the provider owes the patient.
    ///
    /// v8: not an error. Being owed money is good news, and showing it in red under
    /// "Likely error" made Lime Shield sound alarmed about a refund.
    static func creditBalance(_ bill: Bill) -> [BillIssue] {
        guard let due = bill.totals.amountDue, due < -0.01 else { return [] }
        return [BillIssue(
            ruleID: "credit_balance",
            title: "You may be owed a refund",
            detail: "The balance on this statement is \(abs(due).usd) in your favour. Credit balances often sit unrefunded until someone asks for them.",
            severity: .knowYourRights,
            evidence: ["Balance: \(due.usd)"],
            estimatedImpact: abs(due),
            action: "Ask billing to refund the credit balance rather than holding it on the account.")]
    }

    /// 16. More collected than was ever charged.
    ///
    /// v8: this is no longer a "likely error". On a statement where the patient simply
    /// paid more than they owed, this is just a credit balance, which is normal and is
    /// good news. Calling it an error made Lime Shield sound alarmed about a refund.
    static func paymentsExceedCharges(_ bill: Bill) -> [BillIssue] {
        guard bill.totalsAreReliable,
              let pays = bill.totals.payments,
              let charges = bill.totals.totalCharges,
              pays > charges + ReferenceData.mathTolerance else { return [] }
        return [BillIssue(
            ruleID: "payments_exceed_charges",
            title: "You may have paid more than was charged",
            detail: "Payments of \(pays.usd) are shown against \(charges.usd) of charges, a difference of \((pays - charges).usd). That usually means the account is overpaid and you are owed the difference back, though it can also mean a payment was posted to the wrong account.",
            severity: .knowYourRights,
            evidence: ["Payments: \(pays.usd)", "Total charges: \(charges.usd)"],
            estimatedImpact: pays - charges,
            action: "Ask billing to confirm the credit balance and to refund it rather than holding it on the account.")]
    }

    // MARK: 17-23. Charges worth questioning

    /// 17. The same charge repeating on different dates.
    static func repeatedAcrossDates(_ bill: Bill) -> [BillIssue] {
        var groups: [String: [BillLine]] = [:]
        for line in bill.chargeLines {
            guard let amount = line.amount, line.date != nil else { continue }
            let lowered = line.desc.lowercased()
            // Daily items are supposed to repeat.
            if ReferenceData.dayBasedTerms.contains(where: { lowered.contains($0) }) { continue }
            let key = (line.code ?? norm(line.desc)) + "|" + String(Int((amount * 100).rounded()))
            groups[key, default: []].append(line)
        }
        return groups.values.compactMap { lines in
            let dates = Set(lines.map { day($0.date) })
            guard dates.count >= 2 else { return nil }
            let amount = lines[0].amount ?? 0
            return BillIssue(
                ruleID: "repeat_across_dates",
                title: "Same charge on more than one date",
                detail: "\"\(lines[0].desc)\" is billed at the same amount on \(dates.count) different dates. That can be a genuine repeat visit, or the same charge copied forward.",
                severity: .worthChecking,
                evidence: lines.map(ev),
                estimatedImpact: amount * Double(lines.count - 1),
                action: "Ask billing to confirm this service was performed on each of those dates.")
        }
    }

    /// 18. Two office or ER visit charges on the same day.
    static func twoVisitsSameDay(_ bill: Bill) -> [BillIssue] {
        var byDate: [String: [BillLine]] = [:]
        for line in bill.chargeLines {
            guard let code = line.code, ReferenceData.visitCodes.contains(code) else { continue }
            byDate[day(line.date), default: []].append(line)
        }
        return byDate.values.compactMap { lines in
            guard lines.count >= 2 else { return nil }
            let extra = lines.dropFirst().compactMap { $0.amount }.reduce(0, +)
            return BillIssue(
                ruleID: "two_visits_same_day",
                title: "More than one visit charge on the same day",
                detail: "This bill charges for \(lines.count) separate patient visits on one date. That is allowed in some situations, but it is also a common billing error.",
                severity: .worthChecking,
                evidence: lines.map(ev),
                estimatedImpact: extra,
                action: "Ask billing why more than one visit was billed for a single day of care.")
        }
    }

    /// 19. Hospital pricing on drugstore medicine.
    static func drugMarkup(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            guard let amount = line.amount, amount > ReferenceData.drugMarkupThreshold else { return nil }
            let lowered = line.desc.lowercased()
            guard ReferenceData.selfAdministeredDrugs.contains(where: { lowered.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "drug_markup",
                title: "Over-the-counter medicine at hospital prices",
                detail: "\"\(line.desc)\" is billed at \(amount.usd). This is medicine you can buy over the counter for a few dollars. Hospitals may charge more, but the markup is negotiable and some plans won't cover self-administered drugs at all.",
                severity: .worthChecking,
                evidence: [ev(line)],
                estimatedImpact: amount,
                action: "Ask billing to reduce or remove charges for medication you could have taken from home.")
        }
    }

    /// 20. Extra surgeons on the bill.
    static func assistantSurgeon(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            let lowered = line.desc.lowercased()
            guard ReferenceData.assistantSurgeonTerms.contains(where: { lowered.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "assistant_surgeon",
                title: "Assistant surgeon billed separately",
                detail: "\"\(line.desc)\" adds a second surgeon's fee. Assistants are necessary for many operations, but they are also billed when the procedure did not require one, and an out-of-network assistant is a classic surprise charge.",
                severity: .worthChecking,
                evidence: [ev(line)],
                estimatedImpact: line.amount,
                action: "Ask whether an assistant was medically necessary, and whether they were in your insurance network.")
        }
    }

    /// 21. Preventive care is supposed to be free in-network under the ACA.
    static func preventiveWithCharge(_ bill: Bill) -> [BillIssue] {
        guard (bill.totals.amountDue ?? 0) > 0 else { return [] }
        return bill.chargeLines.compactMap { line in
            let lowered = line.desc.lowercased()
            guard ReferenceData.preventiveTerms.contains(where: { lowered.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "preventive_with_charge",
                title: "Preventive care with a balance owing",
                detail: "\"\(line.desc)\" looks like preventive care. Most in-network preventive services are required to be provided at no cost to you under the Affordable Care Act. A balance can still be legitimate if something diagnostic happened during the visit, but it is worth asking.",
                severity: .worthChecking,
                evidence: [ev(line)],
                estimatedImpact: nil,
                action: "Ask whether this was coded as preventive, and if not, why it was coded diagnostic instead.")
        }
    }

    /// 22. Vaccine administration charged to the patient.
    static func vaccineCharge(_ bill: Bill) -> [BillIssue] {
        guard (bill.totals.amountDue ?? 0) > 0 else { return [] }
        return bill.chargeLines.compactMap { line in
            let lowered = line.desc.lowercased()
            let byTerm = ReferenceData.vaccineTerms.contains { lowered.contains($0) }
            let byCode = line.code.map { ReferenceData.vaccineCodes.contains($0) } ?? false
            guard byTerm || byCode else { return nil }
            return BillIssue(
                ruleID: "vaccine_charge",
                title: "Vaccine charge on the bill",
                detail: "\"\(line.desc)\" is a vaccine or its administration fee. Routine immunisations from an in-network provider are usually covered in full.",
                severity: .worthChecking,
                evidence: [ev(line)],
                estimatedImpact: nil,
                action: "Ask your insurer whether this vaccine should have been covered at no cost.")
        }
    }

    /// 23. Add-on fees for the timing of care.
    static func afterHoursFee(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            let lowered = line.desc.lowercased()
            guard ReferenceData.afterHoursTerms.contains(where: { lowered.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "after_hours_fee",
                title: "After-hours or special service fee",
                detail: "\"\(line.desc)\" is a surcharge for when the care happened rather than for the care itself. Many plans do not cover these, and providers often drop them when questioned.",
                severity: .worthChecking,
                evidence: [ev(line)],
                estimatedImpact: line.amount,
                action: "Ask whether this fee is covered by your plan, and ask for it to be waived if it is not.")
        }
    }

    /// 24. Fees for appointments that never happened.
    static func missedAppointmentFee(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            let lowered = line.desc.lowercased()
            guard ReferenceData.missedAppointmentTerms.contains(where: { lowered.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "missed_appointment_fee",
                title: "Fee for a missed or cancelled appointment",
                detail: "\"\(line.desc)\" charges for care that was not given. These fees are not billable to insurance, and are often waived on request, especially for a first occurrence.",
                severity: .worthChecking,
                evidence: [ev(line)],
                estimatedImpact: line.amount,
                action: "Ask for the fee to be waived, and check the cancellation policy you agreed to.")
        }
    }

    // MARK: 25-30. Know your rights

    /// 25. Interest and admin fees added to a medical balance.
    static func interestOrLateFee(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            let lowered = line.desc.lowercased()
            // v7.1 precedence: a line already named by a more specific fee rule is not
            // reported again here, or one charge appears twice in the results.
            if ReferenceData.afterHoursTerms.contains(where: { lowered.contains($0) })
                || ReferenceData.missedAppointmentTerms.contains(where: { lowered.contains($0) }) {
                return nil
            }
            guard ReferenceData.interestTerms.contains(where: { lowered.contains($0) }) else { return nil }
            return BillIssue(
                ruleID: "interest_or_fee",
                title: "Interest or administrative fee added",
                detail: "\"\(line.desc)\" is a fee on top of the care itself. Several states restrict interest on medical debt, and many providers will remove these charges if you set up a payment plan.",
                severity: .knowYourRights,
                evidence: [ev(line)],
                estimatedImpact: line.amount,
                action: "Ask for the fee to be removed and for an interest-free payment plan.")
        }
    }

    /// 26. Observation status changes what insurance pays.
    static func observationStatus(_ bill: Bill) -> [BillIssue] {
        guard textContains(bill, ReferenceData.observationTerms) else { return [] }
        return [BillIssue(
            ruleID: "observation_status",
            title: "You were billed as observation, not admitted",
            detail: "Observation is treated as outpatient care even when you stayed overnight in a hospital bed. It is usually billed differently from an inpatient admission and can leave you owing much more, particularly on Medicare.",
            severity: .knowYourRights,
            evidence: [],
            estimatedImpact: nil,
            action: "Ask whether your stay could be reclassified as inpatient, and ask your insurer how observation is covered under your plan.")]
    }

    /// 27. A bill arriving very late after the service.
    static func timelyFiling(_ bill: Bill) -> [BillIssue] {
        guard let statement = bill.statementDate else { return [] }

        // v7.2: line dates only attach when OCR groups the table rows correctly, which
        // varies with image scale. When they're missing, fall back to every date in the
        // text so the rule doesn't silently stop working on a differently-scanned photo.
        var serviceDates = bill.chargeLines.compactMap { $0.date }
        if serviceDates.count < 2 {
            serviceDates = BillParser.allDates(in: bill.rawText)
                .filter { abs($0.timeIntervalSince(statement)) > 86_400 }
        }
        guard !serviceDates.isEmpty else { return [] }

        let old = serviceDates.filter {
            statement.timeIntervalSince($0) / 86_400 > ReferenceData.timelyFilingDays
        }
        // v7.2: counting beats proportions here. One stray misread date shouldn't fire
        // the rule (that was the bill E false positive), but a sparse parse shouldn't
        // silence it either. Two old dates is the evidence bar; with only one or two
        // dates to go on, all of them must be old.
        let enoughEvidence = serviceDates.count <= 2 ? old.count == serviceDates.count : old.count >= 2
        guard enoughEvidence, let earliest = old.min() else { return [] }
        let days = statement.timeIntervalSince(earliest) / 86_400
        // Ignore absurd gaps: those are misread years, not genuinely ancient bills.
        guard days < 3650 else { return [] }
        return [BillIssue(
            ruleID: "timely_filing",
            title: "This bill arrived a long time after the care",
            detail: "The earliest service on this statement is about \(Int(days / 30)) months before the statement date. Insurers impose deadlines on providers for submitting claims, and when a provider misses that deadline the patient generally cannot be billed for it.",
            severity: .knowYourRights,
            evidence: [],
            estimatedImpact: nil,
            action: "Ask when the claim was first submitted to your insurer, and whether the delay was on the provider's side.")]
    }

    /// 28. Collection pressure and what protections exist.
    static func collectionsPressure(_ bill: Bill) -> [BillIssue] {
        guard textContains(bill, ReferenceData.collectionsTerms) else { return [] }
        return [BillIssue(
            ruleID: "collections",
            title: "This bill mentions collections",
            detail: "Disputed medical bills should not be sent to collections while the dispute is open. Requesting an itemized bill or a billing review in writing creates a record that the account is disputed.",
            severity: .knowYourRights,
            evidence: [],
            estimatedImpact: nil,
            action: "Put your dispute in writing, keep a copy, and ask them to pause collection activity while it is reviewed.")]
    }

    /// 29. Large balances: assistance and payment plans usually exist.
    static func financialAssistance(_ bill: Bill) -> [BillIssue] {
        guard let due = bill.totals.amountDue,
              due >= ReferenceData.financialAssistanceMinDue,
              !textContains(bill, ReferenceData.financialAssistanceTerms) else { return [] }
        return [BillIssue(
            ruleID: "financial_assistance",
            title: "Ask about financial assistance before paying",
            detail: "This bill is for \(due.usd) and says nothing about financial assistance. Nonprofit hospitals are required to have a written assistance policy, and many people who qualify never apply because they were never told it existed. Interest-free payment plans and self-pay discounts are also common.",
            severity: .knowYourRights,
            evidence: ["Amount due: \(due.usd)"],
            estimatedImpact: nil,
            action: "Ask for the financial assistance policy, the self-pay discount, and an interest-free payment plan before paying anything.")]
    }

    /// 30. A bill that never had insurance applied to it.
    static func noInsuranceApplied(_ bill: Bill) -> [BillIssue] {
        guard let due = bill.totals.amountDue, due >= ReferenceData.financialAssistanceMinDue,
              let charges = bill.totals.totalCharges,
              abs(due - charges) < ReferenceData.mathTolerance,
              (bill.totals.adjustments ?? 0) == 0,
              (bill.totals.payments ?? 0) == 0 else { return [] }
        return [BillIssue(
            ruleID: "no_insurance_applied",
            title: "No insurance payment or adjustment shown",
            detail: "You are being asked for the full billed amount with no insurance payment and no contractual adjustment applied. Either the claim was never filed, it was denied, or the provider has you recorded as self-pay.",
            severity: .knowYourRights,
            evidence: ["Total charges: \(charges.usd)", "Amount due: \(due.usd)"],
            estimatedImpact: nil,
            action: "Confirm the provider has your current insurance and ask them to file or refile the claim before you pay.")]
    }
}
