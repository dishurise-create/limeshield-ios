import Foundation

/// What a billing department is likely to say, and a reasonable reply.
///
/// Knowing a charge is questionable and being able to hold your ground on the phone
/// are different things. These are the standard responses people meet, kept short
/// enough to read while the call is happening. They are conversational suggestions,
/// never assertions about what the provider must do.
enum Pushback {

    struct Exchange {
        let theySay: String
        let youSay: String
    }

    static func exchanges(for ruleID: String) -> [Exchange] {
        switch ruleID {

        case "duplicate", "repeat_across_dates":
            return [
                Exchange(theySay: "The service was performed twice.",
                         youSay: "Then please point to each one separately in my medical record, with the time each was performed."),
                Exchange(theySay: "That's just how our system posts it.",
                         youSay: "If it's a posting artefact rather than two services, please remove the duplicate and send a corrected statement."),
            ]

        case "math", "math_statement", "due_exceeds_charges", "payments_exceed_charges":
            return [
                Exchange(theySay: "The total is correct, the detail just displays differently.",
                         youSay: "I'd like a statement where the line items and the total agree. Until they do, I can't tell what I'm paying for."),
            ]

        case "outlier":
            return [
                Exchange(theySay: "That's our standard rate.",
                         youSay: "I understand. What's your self-pay or prompt-payment rate, and what discount can you apply?"),
                Exchange(theySay: "We can't change the price.",
                         youSay: "Then can you send me your financial assistance policy and set up an interest-free payment plan?"),
            ]

        case "not_itemized":
            return [
                Exchange(theySay: "The summary shows everything you owe.",
                         youSay: "I'm asking for the itemized bill with billing codes. I'd like to review it before paying."),
                Exchange(theySay: "That will take a few weeks.",
                         youSay: "That's fine. Please pause collection activity on the account until I've received and reviewed it."),
            ]

        case "vague", "supplies":
            return [
                Exchange(theySay: "That covers supplies used during your care.",
                         youSay: "Could you break it into specific items with codes? I'd like to see what's included."),
                Exchange(theySay: "Those items are always billed that way.",
                         youSay: "My understanding is routine supplies are usually part of the room or procedure fee. Can you confirm why these are separate?"),
            ]

        case "drug_markup":
            return [
                Exchange(theySay: "Medication administered here is billed at our rates.",
                         youSay: "This is something I could have taken from home. Can that charge be reduced or removed?"),
            ]

        case "preventive_with_charge":
            return [
                Exchange(theySay: "The visit became diagnostic, so it isn't preventive.",
                         youSay: "Could you tell me which diagnosis code was used and why? I'd like to check it with my insurer."),
            ]

        case "after_hours_fee", "missed_appointment_fee", "interest_or_fee":
            return [
                Exchange(theySay: "That fee is part of our policy.",
                         youSay: "I understand it's your policy. I'm asking whether you'll waive it, since my plan doesn't cover it."),
            ]

        case "unbundle":
            return [
                Exchange(theySay: "Those were separate tests.",
                         youSay: "Could you confirm they weren't already included in the panel billed on the same day?"),
            ]

        case "surprise_billing":
            return [
                Exchange(theySay: "The provider you saw is out of network.",
                         youSay: "This was emergency care. I believe the No Surprises Act applies, and I'm asking you to rebill at the in-network rate."),
            ]

        case "observation_status":
            return [
                Exchange(theySay: "You were never formally admitted.",
                         youSay: "I stayed overnight in a hospital bed. Can the stay be reviewed for inpatient status, and can you tell me who decides that?"),
            ]

        case "timely_filing":
            return [
                Exchange(theySay: "The balance is still owed regardless of when we billed.",
                         youSay: "When was the claim first submitted to my insurer? If it missed their filing deadline, I don't believe I'm responsible for it."),
            ]

        case "financial_assistance", "no_insurance_applied":
            return [
                Exchange(theySay: "We don't show any insurance on file.",
                         youSay: "Here are my details. Please file the claim before billing me directly."),
                Exchange(theySay: "The balance is due now.",
                         youSay: "Please send me your financial assistance policy and the application, and hold the account while I apply."),
            ]

        case "collections":
            return [
                Exchange(theySay: "The account is already past due.",
                         youSay: "I'm disputing specific charges in writing today. Please note the account as disputed and pause collection activity."),
            ]

        default:
            return [
                Exchange(theySay: "That charge is correct.",
                         youSay: "Could you show me what supports it in the record, and send a written explanation?"),
            ]
        }
    }
}
