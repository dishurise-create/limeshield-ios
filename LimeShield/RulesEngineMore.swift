import Foundation

/// Rules 31 to 45, added in v8.
///
/// Same discipline as everything before it: arithmetic is the only thing ever called an
/// error, judgement calls are phrased as questions, and every rule stays silent when the
/// data it needs wasn't parsed. Each was checked against the clean test bill to confirm
/// it produces nothing on a correct statement.
extension RulesEngine {

    static func furtherRules(_ bill: Bill) -> [BillIssue] {
        var issues: [BillIssue] = []
        issues += quantityMath(bill)
        issues += adjustmentsExceedCharges(bill)
        issues += alreadyPaidConflict(bill)
        issues += duplicateFacilityFee(bill)
        issues += facilityFeeOnOfficeVisit(bill)
        issues += traumaActivation(bill)
        issues += anesthesiaHigh(bill)
        issues += telehealthFullPrice(bill)
        issues += covidTestCharge(bill)
        issues += ambulanceCharge(bill)
        issues += outOfNetworkNonEmergency(bill)
        issues += goodFaithEstimate(bill)
        issues += chargesAfterDischarge(bill)
        issues += missingServiceDates(bill)
        issues += selfPayNoDiscount(bill)
        issues += newbornBilledSeparately(bill)
        return issues
    }

    // MARK: Helpers

    fileprivate static func evidence2(_ line: BillLine) -> String {
        var parts = [line.desc]
        if let code = line.code { parts.append("(\(code))") }
        if let amount = line.amount { parts.append(amount.usd) }
        return parts.joined(separator: " ")
    }

    fileprivate static func has(_ bill: Bill, _ terms: [String]) -> Bool {
        let lowered = bill.rawText.lowercased()
        return terms.contains { lowered.contains($0) }
    }

    fileprivate static func lines(_ bill: Bill, matching terms: [String]) -> [BillLine] {
        bill.chargeLines.filter { line in
            let lowered = line.desc.lowercased()
            return terms.contains { lowered.contains($0) }
        }
    }

    // MARK: 31-33. Arithmetic

    /// 31. Unit price times quantity should equal the line total.
    static func quantityMath(_ bill: Bill) -> [BillIssue] {
        bill.chargeLines.compactMap { line in
            guard let quantity = line.quantity, quantity >= 2,
                  let total = line.amount else { return nil }
            let amounts = BillParser.extractAmounts(from: line.raw).filter { $0 > 0 }
            // Need exactly a unit price and a line total to compare.
            guard amounts.count == 2 else { return nil }
            guard let unit = amounts.min(), let stated = amounts.max(),
                  abs(stated - total) < 0.01, unit < stated else { return nil }
            let expected = unit * Double(quantity)
            guard abs(expected - stated) > 0.01 else { return nil }
            return BillIssue(
                ruleID: "quantity_math",
                title: "Quantity and price don't multiply out",
                detail: "\"\(line.desc)\" shows a unit price of \(unit.usd) and a quantity of \(quantity), which comes to \(expected.usd). The line is billed at \(stated.usd).",
                severity: .likelyError,
                evidence: [evidence2(line)],
                estimatedImpact: abs(stated - expected),
                action: "Ask billing to confirm the unit price and quantity, and to correct the line total.")
        }
    }

    /// 32. Adjustments larger than the charges they're adjusting.
    ///
    /// v8: demoted from "likely error" and gated on a trustworthy parse. On a real
    /// itemization that lists each insurer adjustment and then totals them, an
    /// over-eager parse counted both and made an ordinary statement look impossible.
    static func adjustmentsExceedCharges(_ bill: Bill) -> [BillIssue] {
        guard bill.totalsAreReliable,
              let adjustments = bill.totals.adjustments, adjustments > 0,
              let charges = bill.totals.totalCharges, charges > 0,
              adjustments > charges + ReferenceData.mathTolerance else { return [] }
        return [BillIssue(
            ruleID: "adjustments_exceed_charges",
            title: "Adjustments are larger than the charges",
            detail: "Adjustments of \(adjustments.usd) are applied against \(charges.usd) of charges. That can happen when charges are missing from this page, so check whether this is the whole statement before raising it.",
            severity: .worthChecking,
            evidence: ["Adjustments: \(adjustments.usd)", "Total charges: \(charges.usd)"],
            estimatedImpact: adjustments - charges,
            action: "Ask for a statement that shows how the adjustments were applied to each charge.")]
    }

    /// 33. A balance demanded on an account the bill says is settled.
    static func alreadyPaidConflict(_ bill: Bill) -> [BillIssue] {
        guard let due = bill.totals.amountDue, due > 0,
              has(bill, ReferenceData.paidInFullTerms) else { return [] }
        return [BillIssue(
            ruleID: "already_paid",
            title: "This bill says paid, but still asks for money",
            detail: "The statement contains wording about the account being paid or having no balance, yet it asks for \(due.usd). This can happen when an old statement is reissued or a payment wasn't posted.",
            severity: .likelyError,
            evidence: ["Amount due: \(due.usd)"],
            estimatedImpact: due,
            action: "Ask whether a payment has already been applied, and request a current statement before paying anything.")]
    }

    // MARK: 34-40. Charges worth questioning

    /// 34. More than one facility fee on a single statement.
    static func duplicateFacilityFee(_ bill: Bill) -> [BillIssue] {
        let fees = lines(bill, matching: ReferenceData.facilityFeeTerms)
        guard fees.count >= 2 else { return [] }
        let extra = fees.dropFirst().compactMap { $0.amount }.reduce(0, +)
        return [BillIssue(
            ruleID: "duplicate_facility_fee",
            title: "More than one facility fee",
            detail: "This bill charges \(fees.count) separate facility fees. A facility fee covers the use of the building and its staff, so more than one on a single visit is worth questioning.",
            severity: .worthChecking,
            evidence: fees.map(evidence2),
            estimatedImpact: extra,
            action: "Ask what each facility fee covers and why more than one applies to this visit.")]
    }

    /// 35. Hospital-style facility fee attached to an ordinary office visit.
    static func facilityFeeOnOfficeVisit(_ bill: Bill) -> [BillIssue] {
        let fees = lines(bill, matching: ReferenceData.facilityFeeTerms)
        guard !fees.isEmpty else { return [] }
        let officeVisit = bill.chargeLines.contains { line in
            guard let code = line.code else { return false }
            return ["99211", "99212", "99213", "99214", "99215",
                    "99202", "99203", "99204", "99205"].contains(code)
        }
        guard officeVisit else { return [] }
        return [BillIssue(
            ruleID: "facility_fee_office_visit",
            title: "Facility fee on a normal office visit",
            detail: "A facility fee is billed alongside a standard office visit. This usually happens when a practice is owned by a hospital, and it can add hundreds of dollars to an ordinary appointment. It's legal, but it's negotiable and many patients aren't told about it in advance.",
            severity: .worthChecking,
            evidence: fees.map(evidence2),
            estimatedImpact: fees.compactMap { $0.amount }.reduce(0, +),
            action: "Ask whether you were told about the facility fee before the appointment, and whether it can be reduced or waived.")
        ]
    }

    /// 36. Trauma team activation, one of the largest single fees on any bill.
    static func traumaActivation(_ bill: Bill) -> [BillIssue] {
        lines(bill, matching: ReferenceData.traumaTerms).compactMap { line in
            guard let amount = line.amount, amount >= ReferenceData.traumaNotableAmount else { return nil }
            return BillIssue(
                ruleID: "trauma_activation",
                title: "Trauma team activation fee",
                detail: "\"\(line.desc)\" bills \(amount.usd) for assembling a trauma team. The fee is only supposed to apply when a full trauma team was actually activated to meet you, and it is frequently charged when that didn't happen.",
                severity: .worthChecking,
                evidence: [evidence2(line)],
                estimatedImpact: amount,
                action: "Ask for documentation that a trauma team was activated and present for your arrival.")
        }
    }

    /// 37. Very large anesthesia charges, which are billed by time.
    static func anesthesiaHigh(_ bill: Bill) -> [BillIssue] {
        lines(bill, matching: ["anesthesia", "anesthetic", "anesthesiology"]).compactMap { line in
            guard let amount = line.amount, amount >= ReferenceData.anesthesiaHighAmount else { return nil }
            return BillIssue(
                ruleID: "anesthesia_high",
                title: "Large anesthesia charge",
                detail: "\"\(line.desc)\" is billed at \(amount.usd). Anesthesia is charged by time, so the total depends on how long the procedure actually took. Anesthesia is also one of the most common out-of-network surprises.",
                severity: .worthChecking,
                evidence: [evidence2(line)],
                estimatedImpact: nil,
                action: "Ask for the recorded start and end times, and whether the anesthetist was in your insurance network.")
        }
    }

    /// 38. Telehealth billed like an in-person visit.
    static func telehealthFullPrice(_ bill: Bill) -> [BillIssue] {
        lines(bill, matching: ReferenceData.telehealthTerms).compactMap { line in
            guard let amount = line.amount, amount >= ReferenceData.telehealthHighAmount else { return nil }
            return BillIssue(
                ruleID: "telehealth_price",
                title: "Video visit billed at a high rate",
                detail: "\"\(line.desc)\" is billed at \(amount.usd) for a remote visit. Some plans cover telehealth differently from in-person care, and some providers charge less for it.",
                severity: .worthChecking,
                evidence: [evidence2(line)],
                estimatedImpact: nil,
                action: "Ask what the in-person rate would have been, and how your plan covers telehealth.")
        }
    }

    /// 39. Patient charged for COVID testing.
    static func covidTestCharge(_ bill: Bill) -> [BillIssue] {
        guard (bill.totals.amountDue ?? 0) > 0 else { return [] }
        return bill.chargeLines.compactMap { line in
            let lowered = line.desc.lowercased()
            let isCovid = ReferenceData.covidTerms.contains { lowered.contains($0) }
            let isTest = ReferenceData.testTerms.contains { lowered.contains($0) }
            guard isCovid, isTest, let amount = line.amount, amount > 0 else { return nil }
            return BillIssue(
                ruleID: "covid_test_charge",
                title: "Charge for COVID testing",
                detail: "\"\(line.desc)\" bills \(amount.usd) for coronavirus testing. Coverage rules for these tests have changed over time and vary by plan, so a charge may or may not be correct for the date it was done.",
                severity: .worthChecking,
                evidence: [evidence2(line)],
                estimatedImpact: amount,
                action: "Check with your insurer how testing was covered on that date of service.")
        }
    }

    /// 40. Ambulance transport, a classic surprise bill with a legal gap.
    static func ambulanceCharge(_ bill: Bill) -> [BillIssue] {
        let rides = lines(bill, matching: ReferenceData.ambulanceTerms)
        guard !rides.isEmpty else { return [] }
        return [BillIssue(
            ruleID: "ambulance",
            title: "Ambulance charge",
            detail: "Ambulance bills are one of the most common sources of unexpected charges. Worth knowing: the federal No Surprises Act covers air ambulances, but ground ambulances were left out of it, so protection depends on your state and your plan.",
            severity: .knowYourRights,
            evidence: rides.map(evidence2),
            estimatedImpact: nil,
            action: "Ask your insurer how this transport was covered, and check whether your state limits ground ambulance balance billing.")]
    }

    // MARK: 41-45. Know your rights

    /// 41. Out-of-network billing outside an emergency.
    static func outOfNetworkNonEmergency(_ bill: Bill) -> [BillIssue] {
        let lowered = " " + bill.rawText.lowercased() + " "
        let outOfNetwork = ReferenceData.outOfNetworkTerms.contains { lowered.contains($0) }
        let emergency = ReferenceData.erMarkers.contains { lowered.contains($0) }
        // The emergency case is already covered by the surprise-billing rule.
        guard outOfNetwork, !emergency else { return [] }
        return [BillIssue(
            ruleID: "out_of_network",
            title: "This bill mentions out-of-network care",
            detail: "Out-of-network charges are usually much higher, and your plan may pay little or none of them. If you were not clearly told in advance that this provider was out of network, that's worth raising with both the provider and your insurer.",
            severity: .knowYourRights,
            evidence: [],
            estimatedImpact: nil,
            action: "Ask whether you signed a notice and consent form for out-of-network care, and ask your insurer about an in-network exception.")]
    }

    /// 42. An estimate is not a bill.
    static func goodFaithEstimate(_ bill: Bill) -> [BillIssue] {
        guard has(bill, ReferenceData.estimateTerms) else { return [] }
        return [BillIssue(
            ruleID: "estimate",
            title: "This looks like an estimate, not a bill",
            detail: "This document appears to be an estimate of what care will cost rather than a request for payment. Estimates are useful to keep: if the final bill comes in substantially higher, you may be able to dispute the difference.",
            severity: .knowYourRights,
            evidence: [],
            estimatedImpact: nil,
            action: "Don't pay from an estimate. Keep it, and compare it against the bill when that arrives.")]
    }

    /// 43. Services dated after the patient went home.
    static func chargesAfterDischarge(_ bill: Bill) -> [BillIssue] {
        var dischargeDate: Date?
        for row in bill.rawText.components(separatedBy: "\n") {
            let lowered = row.lowercased()
            guard ReferenceData.dischargeTerms.contains(where: { lowered.contains($0) }) else { continue }
            if let date = BillParser.extractDate(from: row) {
                dischargeDate = date
                break
            }
        }
        guard let discharge = dischargeDate else { return [] }
        let after = bill.chargeLines.filter { line in
            guard let date = line.date else { return false }
            return date.timeIntervalSince(discharge) > 86_400
        }
        guard !after.isEmpty else { return [] }
        return [BillIssue(
            ruleID: "after_discharge",
            title: "Charges dated after you were discharged",
            detail: "\(after.count) charge\(after.count == 1 ? " is" : "s are") dated after the discharge date shown on this statement. That can be legitimate for lab work resulted later, but it can also mean charges from another patient or another stay landed on your account.",
            severity: .worthChecking,
            evidence: after.map(evidence2),
            estimatedImpact: after.compactMap { $0.amount }.reduce(0, +),
            action: "Ask billing to confirm these charges belong to your stay and explain the dates.")]
    }

    /// 44. An itemized bill with no dates at all.
    static func missingServiceDates(_ bill: Bill) -> [BillIssue] {
        guard bill.hasLineDetail else { return [] }
        let dated = bill.chargeLines.filter { $0.date != nil }
        guard dated.isEmpty else { return [] }
        return [BillIssue(
            ruleID: "no_service_dates",
            title: "No dates of service on the charges",
            detail: "None of the charges show a date. Without dates you can't check them against when you were actually treated, which is how charges from another visit, or another patient, go unnoticed.",
            severity: .knowYourRights,
            evidence: [],
            estimatedImpact: nil,
            action: "Ask for an itemized statement that shows the date of service for every charge.")]
    }

    /// 45. Self-pay with no discount applied.
    static func selfPayNoDiscount(_ bill: Bill) -> [BillIssue] {
        guard has(bill, ReferenceData.selfPayTerms),
              !has(bill, ReferenceData.discountTerms),
              let due = bill.totals.amountDue, due > 0 else { return [] }
        return [BillIssue(
            ruleID: "self_pay_no_discount",
            title: "Paying yourself, with no discount shown",
            detail: "This bill treats you as self-pay but shows no discount. Providers routinely accept far less than the list price from insurers, and most will offer an uninsured or prompt-payment discount if you ask. The list price is a starting position, not a fixed price.",
            severity: .knowYourRights,
            evidence: ["Amount due: \(due.usd)"],
            estimatedImpact: nil,
            action: "Ask for the uninsured discount, the prompt-payment rate, and the financial assistance policy before paying.")]
    }

    /// 46. Newborn billed on a separate account.
    static func newbornBilledSeparately(_ bill: Bill) -> [BillIssue] {
        let newborn = lines(bill, matching: ReferenceData.newbornTerms)
        guard !newborn.isEmpty else { return [] }
        return [BillIssue(
            ruleID: "newborn_billing",
            title: "Newborn charges on this bill",
            detail: "Hospitals bill a mother and a baby as two separate patients, which means two deductibles and two sets of charges. Newborns also have to be added to a policy within a limited window after birth, and missing that window is a common and expensive mistake.",
            severity: .knowYourRights,
            evidence: newborn.map(evidence2),
            estimatedImpact: nil,
            action: "Confirm the baby was added to your policy within the enrolment window, and check that mother and baby charges aren't duplicated across both accounts.")]
    }
}
