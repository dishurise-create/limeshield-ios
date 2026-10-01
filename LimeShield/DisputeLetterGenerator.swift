import Foundation

/// Generates the letters: itemized-bill request, review request, refund request.
/// Legal-safety by design (audit pass 4): letters request verification, correction
/// or a refund, and never allege fraud.
enum DisputeLetterGenerator {

    static func letter(for analysis: BillAnalysis, patientName: String) -> String {
        let bill = analysis.bill
        let name = patientName.isEmpty ? "[Your Name]" : patientName
        let provider = bill.providerName ?? "[Provider Name]"
        let account = bill.accountNumber.map { "Account: \($0)" } ?? "Account: [Account Number]"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let today = dateFormatter.string(from: Date())

        // Unitemized bills get the itemized-request letter instead.
        if analysis.issues.contains(where: { $0.ruleID == "not_itemized" }) {
            return """
            \(today)

            \(provider)
            Billing Department

            Re: Request for itemized bill, \(account)

            To whom it may concern,

            I am writing regarding the statement referenced above. Before making payment, \
            I am requesting a fully itemized bill listing each individual charge, the date \
            of service, and the associated billing (CPT/HCPCS) codes.

            Please pause any collection activity on this account until the itemized bill \
            has been provided and I have had a reasonable opportunity to review it.

            Please send the itemized bill to the address or patient portal on file.

            Thank you,

            \(name)
            """
        }

        // A statement whose only news is a credit balance gets a refund request.
        // It asks, and it says "if this is correct", because the figure came from a
        // scan and a credit can be waiting on an insurer rather than owed to the patient.
        if analysis.letterKind == .refund, let credit = analysis.refundableCredit {
            return """
            \(today)

            \(provider)
            Billing Department

            Re: Request for refund of credit balance, \(account)

            To whom it may concern,

            My statement for the account referenced above shows a credit balance of \
            \(credit.usd) in my favor. If this is correct, I am requesting that the \
            credit be refunded to me rather than held on the account.

            Please issue the refund to the original method of payment, or by check to \
            the address on file, and send me an updated statement showing a zero balance.

            If the credit is being held for a pending insurance adjustment or another \
            open charge, please let me know in writing what it is being held for and \
            when it will be resolved.

            Thank you for your assistance.

            Sincerely,

            \(name)
            """
        }

        // Safety net: the letter button is hidden when there is nothing actionable,
        // but never emit a letter with an empty list of concerns.
        guard !analysis.actionableIssues.isEmpty else {
            return "There are no items on this bill that need a review request. Nothing here has to be disputed."
        }

        let concerns = analysis.actionableIssues
            .prefix(8)
            .enumerated()
            .map { index, issue -> String in
                var block = "\(index + 1). \(issue.title)."
                if !issue.evidence.isEmpty {
                    block += " Relevant entries: " + issue.evidence.joined(separator: "; ") + "."
                }
                block += " \(issue.action)"
                return block
            }
            .joined(separator: "\n\n")

        // The same statement can show a credit as well as items to verify.
        let creditParagraph = analysis.refundableCredit.map {
            "\n\nThe statement also shows a credit balance of \($0.usd) in my favor. "
                + "If that is correct once the items above are resolved, please refund it "
                + "rather than holding it on the account."
        } ?? ""

        return """
        \(today)

        \(provider)
        Billing Department

        Re: Request for billing review, \(account)

        To whom it may concern,

        I have reviewed the statement referenced above and would like the following \
        items verified and, where appropriate, corrected before I make payment:

        \(concerns)\(creditParagraph)

        Please provide a written response addressing each item, along with a corrected \
        statement if any adjustments are made. I would also ask that this account not \
        be sent to collections while this review is in progress.

        Thank you for your assistance.

        Sincerely,

        \(name)
        """
    }
}
