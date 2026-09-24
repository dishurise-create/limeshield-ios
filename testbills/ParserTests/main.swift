// Parser + rules regression tests. Compiled together with the app's real
// BillParser, Models, ReferenceData and RulesEngine sources, so nothing here can
// drift from what ships. Run with: testbills/run_parser_tests.sh
//
// Each fixture is a bill whose correct answer is known. Most encode one of the
// "parser rules, do not regress these" from CLAUDE.md.

import Foundation
import CoreGraphics

struct OCRWord: Sendable {
    let text: String
    let box: CGRect
}

var failures = 0
var passes = 0

func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    if condition {
        passes += 1
    } else {
        failures += 1
        print("FAIL  \(name)  \(detail())")
    }
}

func rules(_ bill: Bill) -> Set<String> { Set(RulesEngine.analyze(bill).map(\.ruleID)) }
func chargeSum(_ bill: Bill) -> Double { bill.chargeLines.compactMap(\.amount).reduce(0, +) }
func hasCharge(_ bill: Bill, _ amount: Double) -> Bool {
    bill.chargeLines.contains { abs(($0.amount ?? 0) - amount) < 0.001 }
}

// MARK: Rule 1: summary and total rows are never line items

do {
    let bill = BillParser.parse(text: """
    MERCY HOSPITAL
    08/02/2026 X-RAY CHEST 2 VIEWS 71046 $210.00
    08/02/2026 CBC WITH DIFF 85025 $60.00
    08/02/2026 OFFICE VISIT EST 99213 $180.00
    Subtotal $450.00
    Total Charges $450.00
    Balance Due $450.00
    """)
    check("R1 totals excluded: 3 charge lines", bill.chargeLines.count == 3, "got \(bill.chargeLines.count)")
    check("R1 totals excluded: sum 450", abs(chargeSum(bill) - 450) < 0.01, "got \(chargeSum(bill))")
    check("R1 total charges read", bill.totals.totalCharges == 450)
    check("R1 honest bill: no math finding", !rules(bill).contains("math"), "\(rules(bill))")
}
do {
    // A procedure whose name starts with "TOTAL" is a charge, because it carries a code.
    let bill = BillParser.parse(text: """
    08/02/2026 TOTAL KNEE ARTHROPLASTY 27447 $30,000.00
    Total Charges $30,000.00
    """)
    check("R1 'TOTAL KNEE' with code is a charge", hasCharge(bill, 30000), "\(bill.chargeLines.map(\.raw))")
}
do {
    let bill = BillParser.parse(text: "0001 TOTAL CHARGES 1284.00")
    check("R1 revenue-code total row is not a line", bill.chargeLines.isEmpty)
    check("R1 revenue-code total row sets total", bill.totals.totalCharges == 1284)
}

// MARK: Rule 2: non-charge keywords use word boundaries

do {
    let bill = BillParser.parse(text: """
    08/02/2026 INTEREST ON UNPAID BALANCE $12.00
    08/05/2026 PAYMENT RECEIVED THANK YOU -$50.00
    08/05/2026 PAID BY PATIENT $25.00
    """)
    check("R2 'unpaid' does not match 'paid'", hasCharge(bill, 12), "\(bill.chargeLines.map(\.raw))")
    check("R2 payment row is not a charge", !hasCharge(bill, 50))
    check("R2 'paid' row is not a charge", !hasCharge(bill, 25))
}

// MARK: Rule 3: keywords only checked before the first amount

do {
    let bill = BillParser.parse(text: "08/02/2026 STERILE DRESSING KIT $54.00 Coinsurance 20%")
    check("R3 column header after amount doesn't disqualify", hasCharge(bill, 54), "\(bill.chargeLines.map(\.raw))")
}
do {
    let bill = BillParser.parse(text: "08/02/2026 COINSURANCE $54.00")
    check("R3 keyword before amount does disqualify", !hasCharge(bill, 54))
}

// MARK: Rule 4: amounts without thousands separators

do {
    check("R4 1284.00 not truncated", BillParser.extractAmounts(from: "ROOM AND BOARD 1284.00") == [1284])
    check("R4 12840.50 not truncated", BillParser.extractAmounts(from: "OR TIME 12840.50") == [12840.5])
    check("R4 grouped 1,284.00", BillParser.extractAmounts(from: "$1,284.00") == [1284])
    check("R4 negative forms", BillParser.extractAmounts(from: "-$500.00 $-78.50 (20.00) 5.00-") == [-500, -78.5, -20, -5])
}

// MARK: Rule 5: multi-column rows silence the total-dependent rules

do {
    // Charges / adjustments / balance columns. Summing leftmost gives more than the
    // stated total only because of the layout, so the math rule must stay quiet.
    let bill = BillParser.parse(text: """
    STANFORD HEALTH CARE
    08/02/2026 CT HEAD W/O CONTRAST 70450 1250.00 -900.00 350.00
    08/02/2026 ED VISIT LEVEL 4 99284 980.00 -700.00 280.00
    08/02/2026 CMP 80053 310.00 -250.00 60.00
    08/02/2026 CBC 85025 95.00 -70.00 25.00
    Total Charges 2500.00
    Amount Due 715.00
    """)
    check("R5 ambiguous flag set", bill.hasAmbiguousAmountRows == true)
    check("R5 math unreliable", !bill.mathIsReliable)
    check("R5 no math finding", !rules(bill).contains("math"), "\(rules(bill))")
    check("R5 no statement math finding", !rules(bill).contains("math_statement"))
    check("R5 descriptions don't carry other columns' numbers",
          bill.lines.allSatisfy { !$0.desc.contains("900") && !$0.desc.contains("350") },
          "\(bill.lines.map(\.desc))")
}

// MARK: Rule 6: EOB vs provider itemization

do {
    let bill = BillParser.parse(text: """
    BLUE SHIELD
    EXPLANATION OF BENEFITS
    THIS IS NOT A BILL
    Claim Number 99812
    OFFICE VISIT 99213 $180.00 $120.00
    """)
    check("R6 EOB detected", bill.kind == .insurerEOB)
    check("R6 EOB stops analysis", rules(bill) == ["eob"], "\(rules(bill))")
}
do {
    let bill = BillParser.parse(text: """
    CITY HOSPITAL
    ITEMIZED STATEMENT
    THIS IS NOT A BILL
    08/02/2026 ECG ROUTINE 12 LEADS 93000 $150.00
    08/02/2026 ECG ROUTINE 12 LEADS 93000 $150.00
    08/02/2026 CBC 85025 $60.00
    """)
    check("R6 itemization detected", bill.kind == .providerItemization)
    check("R6 itemization is analysed", rules(bill).contains("duplicate"), "\(rules(bill))")
}
do {
    let bill = BillParser.parse(text: """
    THIS IS NOT A BILL
    Member ID XJ4421
    Allowed amount $90.00
    """)
    check("R6 'not a bill' + insurer signals = EOB", bill.kind == .insurerEOB)
}

// MARK: Known-answer bills

do {
    // The built-in demo bill: a duplicated ECG, and lines that sum past the total.
    let bill = BillParser.parse(text: SampleBill.text)
    let found = rules(bill)
    check("Sample: duplicate found", found.contains("duplicate"), "\(found)")
    check("Sample: math found (1190 > 1040)", found.contains("math"), "\(found)")
}
do {
    // Honest statement with payments and adjustments listed as rows.
    let bill = BillParser.parse(text: """
    VALLEY CLINIC
    Statement Date 09/01/2026
    Previous Balance $0.00
    08/02/2026 OFFICE VISIT NEW 99203 $250.00
    08/02/2026 VENIPUNCTURE 36415 $25.00
    08/02/2026 LIPID PANEL 80061 $75.00
    08/20/2026 INSURANCE PAYMENT -$200.00
    08/20/2026 CONTRACTUAL ADJUSTMENT -$100.00
    Total Charges $350.00
    Payments $200.00
    Total Adjustments $100.00
    Amount Due $50.00
    """)
    let found = rules(bill)
    check("Honest: 3 charges", bill.chargeLines.count == 3, "\(bill.chargeLines.map(\.raw))")
    check("Honest: no math", !found.contains("math"), "\(found)")
    check("Honest: no statement math", !found.contains("math_statement"), "\(found) \(bill.totals)")
    check("Honest: no 'error' severity at all",
          !RulesEngine.analyze(bill).contains { $0.severity == .likelyError },
          "\(RulesEngine.analyze(bill).filter { $0.severity == .likelyError }.map(\.ruleID))")
}
do {
    // Statement equation that genuinely doesn't add up.
    let bill = BillParser.parse(text: """
    Previous Balance $0.00
    08/02/2026 OFFICE VISIT NEW 99203 $250.00
    08/02/2026 VENIPUNCTURE 36415 $25.00
    08/02/2026 LIPID PANEL 80061 $75.00
    Total Charges $350.00
    Payments $200.00
    Total Adjustments $100.00
    Amount Due $150.00
    """)
    check("Bad statement: math_statement fires", rules(bill).contains("math_statement"), "\(rules(bill)) \(bill.totals)")
}
// MARK: Real statements that once drew false red findings

do {
    // Stanford Health Care's public sample statement, as OCR actually read it.
    // Honest: $627.00 charged, $313.50 adjusted, $313.50 due. Must stay silent.
    let bill = BillParser.parse(text: """
    Stanford Monthly Statement
    HEALTH CARE
    Page 1 of 2
    STANFORD MEDICINE
    • YOUR IN FORMATION • YOUR ACCOUNT SUMMARY
    Statement Date 6/27/2016 Total Charges $627.00
    Guarantor Name DOE SR, JOHN Patient Payments $0.00
    123456789 Insurance Payments $0.00
    Guarantor ID # Insurance Adjustments $0.00
    4 Account Numbers Located on following pages Other Adjustments $-313.50
    Payment Due Date 7/25/2016 10
    AMOUNT DUE NOW $313.50 11
    Guarantor ID 123456789
    Statement Date 6/27/2016
    HEALTH CARE 16 Amount Due $313.50
    """)
    let found = RulesEngine.analyze(bill)
    check("Stanford: no likely-error findings",
          !found.contains { $0.severity == .likelyError }, "\(found.map(\.ruleID))")
    check("Stanford: no math finding", !found.contains { $0.ruleID.hasPrefix("math") })
}
do {
    // Overpaid statement. A credit balance is good news, not a provider error.
    let bill = BillParser.parse(text: """
    GRANITE STATE DERMATOLOGY
    PATIENT STATEMENT
    Statement Date 09/01/2026
    DATE DESCRIPTION CODE QTY AMOUNT
    08/04/26 OFFICE VISIT LEVEL 3 99213 1 $185.00
    08/04/26 SKIN BIOPSY SINGLE LESION 11102 1 $225.00
    08/04/26 SPECIMEN HANDLING 99000 $0.00
    08/04/26 PATIENT EDUCATION MATERIALS 1 NO CHARGE
    08/20/26 PATIENT PAYMENT -$500.00
    Total Charges $410.00
    Payments Received -$500.00
    Credit Balance -$90.00
    """)
    let found = RulesEngine.analyze(bill)
    check("Granite: refund flagged", found.contains { $0.ruleID == "credit_balance" }, "\(found.map(\.ruleID))")
    check("Granite: nothing red", !found.contains { $0.severity == .likelyError },
          "\(found.filter { $0.severity == .likelyError }.map(\.ruleID))")
}

// MARK: Rule coverage: every rule must be able to fire

// One small bill per rule, built so that rule (and ideally only that rule's
// concern) is present. A rule no bill can trigger is decoration.
let coverage: [(rule: String, text: String)] = [
    ("quantity_math", """
     DATE DESCRIPTION CODE QTY UNIT PRICE AMOUNT
     08/02/2026 SALINE FLUSH J7050 4 $10.00 $45.00
     """),
    ("adjustments_exceed_charges", """
     08/02/2026 OFFICE VISIT 99213 $180.00
     Total Charges $180.00
     Total Adjustments $400.00
     """),
    ("already_paid", """
     Your account has been paid in full. Thank you.
     Amount Due $120.00
     """),
    ("duplicate_facility_fee", """
     08/02/2026 FACILITY FEE $300.00
     08/02/2026 HOSPITAL FEE $250.00
     """),
    ("facility_fee_office_visit", """
     08/02/2026 OFFICE VISIT EST 99213 $180.00
     08/02/2026 FACILITY FEE $300.00
     """),
    ("trauma_activation", "08/02/2026 TRAUMA ACTIVATION LEVEL 1 $9,500.00"),
    ("anesthesia_high", "08/02/2026 ANESTHESIA GENERAL 00790 $4,200.00"),
    ("telehealth_price", "08/02/2026 VIDEO VISIT 99213 $320.00"),
    ("covid_test_charge", """
     08/02/2026 COVID-19 PCR TEST 87635 $150.00
     Amount Due $150.00
     """),
    ("ambulance", "08/02/2026 AMBULANCE TRANSPORT ALS A0427 $1,800.00"),
    ("out_of_network", """
     Provider is out of network for your plan.
     08/02/2026 PHYSICAL THERAPY 97110 $140.00
     """),
    ("estimate", """
     GOOD FAITH ESTIMATE
     08/02/2026 MRI KNEE 73721 $1,200.00
     """),
    ("after_discharge", """
     Discharge Date 08/03/2026
     08/02/2026 ROOM AND BOARD $2,000.00
     08/09/2026 PHARMACY $85.00
     """),
    ("self_pay_no_discount", """
     Self-pay account
     08/02/2026 X-RAY CHEST 71046 $210.00
     Amount Due $210.00
     """),
    ("newborn_billing", "08/02/2026 NEWBORN NURSERY CARE $1,100.00"),
    ("due_exceeds_charges", """
     08/02/2026 OFFICE VISIT 99213 $180.00
     Total Charges $180.00
     Amount Due $260.00
     """),
    ("two_visits_same_day", """
     08/02/2026 OFFICE VISIT 99213 $180.00
     08/02/2026 OFFICE VISIT 99214 $260.00
     """),
    ("assistant_surgeon", "08/02/2026 ASSISTANT SURGEON FEE $1,400.00"),
    ("vaccine_charge", """
     08/02/2026 FLU SHOT 90686 $45.00
     Amount Due $45.00
     """),
    ("date_anomaly", """
     Statement Date 08/15/2026
     08/28/2026 LAB WORK 80053 $120.00
     """),
    ("high_intensity", "08/02/2026 ED VISIT LEVEL 5 99285 $2,400.00"),
    ("surprise_billing", """
     EMERGENCY DEPARTMENT
     Physician is out-of-network
     08/02/2026 ED VISIT 99284 $980.00
     """),
]
for (rule, text) in coverage {
    let found = rules(BillParser.parse(text: text))
    check("Coverage: \(rule) fires", found.contains(rule), "got \(found.sorted())")
}

// MARK: Rules that must stay silent on honest bills

do {
    // "Must be paid in full" is an instruction, not a claim the account is settled.
    let bill = BillParser.parse(text: """
    08/02/2026 OFFICE VISIT 99213 $180.00
    Balance must be paid in full within 30 days.
    Amount Due $180.00
    """)
    check("already_paid silent on payment instruction", !rules(bill).contains("already_paid"), "\(rules(bill))")
}
do {
    // Two figures on a quantity row with no unit-price column: charge and insurer
    // payment, not unit price and total. Multiplying them would be an accusation.
    let bill = BillParser.parse(text: """
    DATE DESCRIPTION CODE QTY CHARGE INS PAID
    08/02/2026 PHYSICAL THERAPY 97110 3 $300.00 $80.00
    """)
    check("quantity_math silent without unit-price column", !rules(bill).contains("quantity_math"), "\(rules(bill))")
}
do {
    // Correct unit-price arithmetic.
    let bill = BillParser.parse(text: """
    DATE DESCRIPTION CODE QTY UNIT PRICE AMOUNT
    08/02/2026 SALINE FLUSH J7050 4 $10.00 $40.00
    """)
    check("quantity_math silent when it multiplies out", !rules(bill).contains("quantity_math"), "\(rules(bill))")
}
do {
    // Only arithmetic may be red.
    let arithmetic: Set<String> = ["math", "math_statement", "due_exceeds_charges", "quantity_math"]
    var red = Set<String>()
    for (_, text) in coverage {
        for issue in RulesEngine.analyze(BillParser.parse(text: text)) where issue.severity == .likelyError {
            red.insert(issue.ruleID)
        }
    }
    check("Only arithmetic rules are red", red.isSubset(of: arithmetic), "non-arithmetic red: \(red.subtracting(arithmetic))")
}

do {
    // UB-04 style lines: revenue code, description, MMDDYY date, CPT, amount.
    // From a real scan (Meridian). Dates are present, and a coded line isn't vague.
    let bill = BillParser.parse(text: """
    0250 PHARMACY GENERAL 030126 $1,284.60
    0270 MED SURG SUPPLIES 030126 $938.75
    0308 LABORATORY GENERAL 030126 80053 $266.80
    Total Charges $2,490.15
    """)
    let found = RulesEngine.analyze(bill)
    check("Compact dates: no 'no service dates'", !found.contains { $0.ruleID == "no_service_dates" },
          "\(found.map(\.ruleID))")
    check("Coded line not vague", !found.contains { $0.ruleID == "vague" && $0.evidence.joined().contains("80053") })
    check("Uncoded general line still vague", found.contains { $0.ruleID == "vague" && $0.evidence.joined().contains("PHARMACY") })
}
do {
    let bill = BillParser.parse(text: """
    PHARMACY $1,284.60
    SUPPLIES $938.75
    LAB $266.80
    """)
    check("Truly undated lines still flagged", rules(bill).contains("no_service_dates"), "\(rules(bill))")
}

// MARK: Dates and quantities

do {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let d2 = BillParser.extractDate(from: "06/14/25").map { cal.component(.year, from: $0) }
    let d4 = BillParser.extractDate(from: "08/20/2026").map { cal.component(.year, from: $0) }
    check("2-digit year is 2025", d2 == 2025, "\(String(describing: d2))")
    check("4-digit year is 2026", d4 == 2026, "\(String(describing: d4))")
    check("invalid month rejected", BillParser.extractDate(from: "13/01/2026") == nil)
}
do {
    let bill = BillParser.parse(text: "08/02/2026 EMERGENCY DEPT VISIT LEVEL 3 99283 $390.00")
    check("Level 3 keeps its '3'", bill.lines.first?.desc.contains("LEVEL 3") == true, "\(bill.lines.map(\.desc))")
    check("Code read", bill.lines.first?.code == "99283")
}
do {
    let bill = BillParser.parse(text: "08/02/2026 SALINE FLUSH J7050 4 $40.00")
    check("Positional quantity", bill.lines.first?.quantity == 4, "\(String(describing: bill.lines.first))")
}

// MARK: OCR row grouping (Vision y origin is bottom-left)

do {
    func w(_ t: String, x: CGFloat, y: CGFloat) -> OCRWord {
        OCRWord(text: t, box: CGRect(x: x, y: y, width: 0.1, height: 0.02))
    }
    // Words delivered column by column, as Vision sometimes does.
    let words = [
        w("CITY", x: 0.05, y: 0.95), w("HOSPITAL", x: 0.2, y: 0.95),
        w("CBC", x: 0.05, y: 0.80), w("CMP", x: 0.05, y: 0.70),
        w("85025", x: 0.5, y: 0.80), w("80053", x: 0.5, y: 0.70),
        w("$60.00", x: 0.8, y: 0.803), w("$120.00", x: 0.8, y: 0.698),
        w("Total", x: 0.05, y: 0.60), w("Charges", x: 0.15, y: 0.60), w("$180.00", x: 0.8, y: 0.60),
    ]
    let bill = BillParser.parse(pages: [words])
    check("OCR: top row first", bill.rawText.hasPrefix("CITY HOSPITAL"), bill.rawText)
    check("OCR: amounts stay on their rows", hasCharge(bill, 60) && hasCharge(bill, 120), bill.rawText)
    check("OCR: total read", bill.totals.totalCharges == 180, bill.rawText)

    let page2 = [w("Total", x: 0.05, y: 0.5), w("Charges", x: 0.15, y: 0.5), w("$999.00", x: 0.8, y: 0.5)]
    let two = BillParser.parse(pages: [words, page2])
    check("OCR: two different totals = two bills", two.multipleBillsDetected == true)
    check("OCR: two bills stops analysis", rules(two) == ["multiple_bills"], "\(rules(two))")
}

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
