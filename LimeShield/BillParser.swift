import Foundation
import CoreGraphics

/// Turns raw OCR words into a structured Bill.
///
/// Pass-3 hardening (see RULES_AUDIT.md): words are grouped into visual ROWS by
/// vertical position before any interpretation, so amounts stay attached to their
/// descriptions even when OCR reading order walks down table columns. Every parsed
/// field is optional, and the rules engine skips what isn't there.
enum BillParser {

    // MARK: Public

    static func parse(pages: [[OCRWord]]) -> Bill {
        var bill = Bill()
        var allRows: [String] = []

        for page in pages {
            let rows = groupIntoRows(page)
            allRows.append(contentsOf: rows)
        }
        bill.rawText = allRows.joined(separator: "\n")

        let lowered = bill.rawText.lowercased()
        bill.documentKind = detectDocumentKind(in: lowered)
        bill.isLikelyEOB = bill.documentKind == .insurerEOB
        bill.providerName = detectProviderName(rows: allRows)
        bill.accountNumber = firstMatch(in: bill.rawText,
                                        pattern: #"(?i)account\s*(?:number|no\.?|#)?\s*[:#]?\s*([A-Z0-9-]{4,20})"#)
        bill.statementDate = detectStatementDate(rows: allRows)

        for row in allRows {
            interpret(row: row, into: &bill)
        }
        bill.multipleBillsDetected = looksLikeMultipleBills(rows: allRows)
        return bill
    }

    /// One bill has one "total charges" figure, however many pages it runs to. Two
    /// different figures means the user photographed two different bills, and summing
    /// their line items together would produce a nonsense math finding.
    private static func looksLikeMultipleBills(rows: [String]) -> Bool {
        var totals = Set<Int>()
        for row in rows {
            let lowered = row.lowercased()
            guard matches(lowered, any: ["total charges", "total new charges", "charges this period"]),
                  let amount = extractAmounts(from: row).last, amount > 0 else { continue }
            totals.insert(Int((amount * 100).rounded()))
        }
        return totals.count > 1
    }

    /// Parse plain text (used by the built-in sample bill and tests).
    static func parse(text: String) -> Bill {
        var bill = Bill()
        let rows = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        bill.rawText = rows.joined(separator: "\n")
        let lowered = bill.rawText.lowercased()
        bill.documentKind = detectDocumentKind(in: lowered)
        bill.isLikelyEOB = bill.documentKind == .insurerEOB
        bill.providerName = detectProviderName(rows: rows)
        bill.statementDate = detectStatementDate(rows: rows)
        for row in rows { interpret(row: row, into: &bill) }
        return bill
    }

    // MARK: Row grouping

    private static func groupIntoRows(_ words: [OCRWord]) -> [String] {
        guard !words.isEmpty else { return [] }
        // Vision: y origin at bottom; sort top-to-bottom by descending midY.
        let sorted = words.sorted { $0.box.midY > $1.box.midY }
        var rows: [[OCRWord]] = []
        var current: [OCRWord] = []
        var currentY: CGFloat = .greatestFiniteMagnitude

        for word in sorted {
            if current.isEmpty || abs(word.box.midY - currentY) < 0.011 {
                current.append(word)
                if current.count == 1 { currentY = word.box.midY }
            } else {
                rows.append(current)
                current = [word]
                currentY = word.box.midY
            }
        }
        if !current.isEmpty { rows.append(current) }

        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }
                .map { $0.text }
                .joined(separator: " ")
        }
    }

    // MARK: Row interpretation

    /// v8: a row is now classified before it is read, because the old code treated
    /// every row carrying a dollar figure as a charge. On real statements that meant
    /// payments, insurance adjustments, subtotals and running balances were all summed
    /// as if the provider had billed them, which produced confident false accusations
    /// against honest bills. See the v8 notes on Bill.mathIsReliable.
    private static func interpret(row: String, into bill: inout Bill) {
        let lowered = row.lowercased().trimmingCharacters(in: .whitespaces)
        let amounts = extractAmounts(from: row)
        let code = extractCode(from: row)

        // 1. Summary and total rows: never line items, whatever else they contain.
        if isSummaryRow(lowered, hasCode: code != nil) {
            recordTotals(lowered, amounts, into: &bill)
            return
        }

        guard !amounts.isEmpty else { return }

        // 2. Several money columns on one row means we cannot tell which is the charge.
        //    Take the leftmost, which is where the Charges column sits on every layout
        //    we have seen, and flag the bill so the arithmetic rules stay quiet.
        let amount = amounts[0]
        if amounts.count >= 2 {
            bill.hasAmbiguousAmountRows = true
        } else if isNonChargeRow(descriptionPart(of: lowered)) {
            // 3. Payments, credits, discounts and adjustments are money moving the
            //    other way. Record them as totals, never as charges.
            bill.creditLineCount = (bill.creditLineCount ?? 0) + 1
            recordTotals(lowered, amounts, into: &bill)
            return
        }

        // 4. A negative or bracketed figure is a credit even without the wording.
        guard amount > 0 else {
            bill.creditLineCount = (bill.creditLineCount ?? 0) + 1
            return
        }

        var line = BillLine(raw: row, desc: row)
        line.amount = amount
        line.code = code
        line.date = extractDate(from: row)

        // v6: columns run DATE · DESCRIPTION · CODE · QTY · AMOUNT, so strip from the
        // RIGHT: amount, then quantity, then code. Order matters, since stripping blind
        // trailing digits would eat the "3" in "EMERGENCY DEPT VISIT LEVEL 3".
        var desc = row
        desc = desc.replacingOccurrences(of: datePattern, with: "", options: .regularExpression)
        if amounts.count >= 2 {
            // Multi-column row: every figure on it belongs to some column, so remove
            // them all rather than leaving the neighbouring column's number in the
            // description the user reads.
            desc = desc.replacingOccurrences(of: amountPattern, with: "", options: .regularExpression)
        } else {
            desc = strippingTrailing(amountPattern, from: desc)
        }

        // A bare 1-3 digit token sitting between the code and the amount is a quantity.
        if let qtyToken = trailingToken(of: desc), qtyToken.count <= 3,
           let qty = Int(qtyToken) {
            line.quantity = qty
            desc = strippingTrailing(#"\b\d{1,3}\b"#, from: desc)
        }
        if let code = line.code {
            desc = strippingTrailing("\\b\(NSRegularExpression.escapedPattern(for: code))\\b", from: desc)
        }
        // Explicit "QTY: n" wording wins over the positional guess.
        if let explicit = extractQuantity(from: row) { line.quantity = explicit }

        desc = desc.trimmingCharacters(in: CharacterSet(charactersIn: " -–|:\t"))
        line.desc = desc.isEmpty ? row : desc

        bill.lines.append(line)
    }

    /// Removes the LAST match of `pattern` from `text` (nothing if it doesn't match).
    private static func strippingTrailing(_ pattern: String, from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        guard let last = regex.matches(in: text, range: range).last,
              let r = Range(last.range, in: text) else { return text }
        var result = text
        result.removeSubrange(r)
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func trailingToken(of text: String) -> String? {
        text.split(separator: " ").last.map(String.init)
    }

    // MARK: Token extraction

    /// v8. Two fixes over the old `\(?\$?\s?\d{1,3}(?:,\d{3})*\.\d{2}\)?-?`.
    ///
    /// The comma group was optional AND capped at three leading digits, so an amount
    /// written without separators lost its leading digits: on a UB-04 style statement
    /// "1284.00" matched starting at the second character and was read as 284.00.
    /// Institutional bills print amounts without commas, so every large figure on them
    /// was wrong. The alternation now requires either a properly grouped number or a
    /// plain run of digits.
    ///
    /// A leading minus is also accepted now, in both "-$500.00" and "$-78.50" forms,
    /// so a payment line is recognised as negative instead of being read as a charge.
    private static let amountPattern =
        #"-?\(?\$?\s?-?(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2}\)?-?"#
    private static let datePattern = #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#

    // MARK: Row classification (v8)

    /// Rows that summarise other rows. Matched as a prefix, because a summary label
    /// starts its line, while a real charge may merely mention one of these words.
    private static let summaryPrefixes = [
        "total", "subtotal", "sub total", "grand total", "claim total",
        "balance", "amount due", "amount paid", "amount enclosed",
        "previous balance", "balance forward", "credit balance", "account balance",
        "current balance", "current hospital account balance",
        "payments", "payment received", "patient balance", "insurance balance",
        "patient responsibility", "statement total", "new charges",
        "charges this", "charges page", "please pay", "pay this amount",
        "insurance payments", "patient payments", "insurance adjustments",
        "other adjustments", "total credits"
    ]

    /// "TOTAL KNEE ARTHROPLASTY" is a procedure, not a subtotal. When a prefix could
    /// plausibly open a real charge description, a billing code on the row vetoes it.
    private static let prefixesNeedingCodeCheck: Set<String> = ["total", "balance"]

    /// Phrases that mean a summary row wherever they appear, including after a
    /// revenue code such as "0001 TOTAL CHARGES".
    private static let summaryPhrases = [
        "total charges", "amount due", "balance due", "previous balance",
        "total insurance payments", "claim totals"
    ]

    /// Money moving toward the patient rather than away. Never a charge.
    ///
    /// Matched on whole words. Substring matching flagged "INTEREST ON UNPAID BALANCE"
    /// as a credit, because "unpaid" contains "paid", which silently deleted a real
    /// charge from the bill.
    private static let nonChargeWordPattern =
        #"\b(payments?|paid|credits?|discounts?|write[- ]?offs?|refunds?|savings|contractual|allowances?|coinsurance|co-insurance|deductible|copay(?:ment)?s?|co-pay|allowed|adj|adjs|adjustments?)\b"#

    /// Multi-word markers that are unambiguous wherever they appear.
    private static let nonChargePhrases = [
        "not covered", "plan paid", "insurance pd", "allowed amount", "amount allowed"
    ]

    private static func isSummaryRow(_ lowered: String, hasCode: Bool) -> Bool {
        let trimmed = lowered.trimmingCharacters(in: CharacterSet(charactersIn: " |*#-·•"))
        for prefix in summaryPrefixes where trimmed.hasPrefix(prefix) {
            let root = prefix.split(separator: " ").first.map(String.init) ?? prefix
            if hasCode && prefixesNeedingCodeCheck.contains(root) { continue }
            return true
        }
        return matches(trimmed, any: summaryPhrases)
    }

    /// The part of a row that precedes its first dollar figure. On every bill layout a
    /// description sits to the left of its own amount, so words appearing after the
    /// amount belong to some other column and must not describe this charge. Without
    /// this, "STERILE DRESSING KIT $54.00   Coinsurance 20%" was thrown away as a
    /// credit because of a word from the insurance column beside it.
    private static func descriptionPart(of lowered: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: amountPattern) else { return lowered }
        let range = NSRange(lowered.startIndex..., in: lowered)
        guard let first = regex.firstMatch(in: lowered, range: range),
              let r = Range(first.range, in: lowered) else { return lowered }
        return String(lowered[lowered.startIndex..<r.lowerBound])
    }

    private static func isNonChargeRow(_ lowered: String) -> Bool {
        if matches(lowered, any: nonChargePhrases) { return true }
        return firstMatch(in: lowered, pattern: nonChargeWordPattern) != nil
    }

    /// Files a summary or credit row into the right total. Called for rows we have
    /// already decided are not charges.
    private static func recordTotals(_ lowered: String, _ amounts: [Double],
                                     into bill: inout Bill) {
        guard let amount = amounts.last else { return }

        if matches(lowered, any: ["total charges", "total new charges",
                                  "charges this period", "total hospital charges"]) {
            if amount > 0 { bill.totals.totalCharges = bill.totals.totalCharges ?? amount }
            return
        }
        if matches(lowered, any: ["amount due", "balance due", "total due", "please pay",
                                  "patient balance", "pay this amount", "amount due now",
                                  "patient responsibility", "credit balance"]) {
            bill.totals.amountDue = bill.totals.amountDue ?? amount
            return
        }
        if matches(lowered, any: ["previous balance", "balance forward"]) {
            bill.totals.previousBalance = bill.totals.previousBalance ?? amount
            return
        }
        if matches(lowered, any: ["payment", "amount paid"]) {
            bill.totals.payments = bill.totals.payments ?? abs(amount)
            return
        }
        if matches(lowered, any: ["adjustment", "insurance paid", "plan paid",
                                  "discount", "write-off", "write off", "credit"]) {
            // A "total adjustments" line already contains the individual ones, so it
            // replaces them instead of being added on top. Without this, a statement
            // that lists each adjustment and then totals them counts everything twice
            // and looks like the provider adjusted more than it ever charged.
            if lowered.hasPrefix("total") || lowered.contains("total insurance") {
                bill.totals.adjustments = abs(amount)
                bill.adjustmentsFromTotalRow = true
            } else if bill.adjustmentsFromTotalRow != true {
                bill.totals.adjustments = (bill.totals.adjustments ?? 0) + abs(amount)
            }
            return
        }
    }

    /// v8. "This is not a bill" used to mean one thing: stop. But a hospital's itemized
    /// statement carries that same sentence, and an itemized statement is exactly the
    /// document Lime Shield tells people to go and request. Refusing to read it meant
    /// the app sent someone off to fetch the one page it could most usefully check, and
    /// then declined to look at it.
    private static func detectDocumentKind(in lowered: String) -> DocumentKind {
        let itemization = ["itemization of services", "itemization of charges",
                           "itemized statement", "itemized bill", "itemized detail",
                           "detail of charges", "hospital charges", "itemization"]
        let insurerSignals = ["explanation of benefits", "claim number", "member id",
                              "allowed amount", "plan paid", "your plan paid",
                              "claim totals", "reason code", "plan savings",
                              "covered by this plan"]

        if lowered.contains("explanation of benefits") { return .insurerEOB }
        if itemization.contains(where: { lowered.contains($0) }) { return .providerItemization }
        if lowered.contains("this is not a bill") {
            let looksLikeInsurer = insurerSignals.contains { lowered.contains($0) }
            return looksLikeInsurer ? .insurerEOB : .providerItemization
        }
        return .bill
    }

    static func extractAmounts(from text: String) -> [Double] {
        matchesAll(in: text, pattern: amountPattern).compactMap { raw in
            // Parentheses, a leading minus and a trailing minus are all used on real
            // statements to mean a credit.
            let negative = raw.contains("(") || raw.contains("-")
            let cleaned = raw.filter { $0.isNumber || $0 == "." }
            guard let value = Double(cleaned) else { return nil }
            return negative ? -value : value
        }
    }

    static func extractCode(from text: String) -> String? {
        // CPT: standalone 5 digits. HCPCS: letter + 4 digits.
        if let cpt = firstMatch(in: text, pattern: #"(?<![\d.,])(\d{5})(?![\d.,])"#) {
            return cpt
        }
        return firstMatch(in: text, pattern: #"\b([A-Z]\d{4})\b"#)
    }

    /// v7.3: dates are now assembled from their digits instead of being guessed at with
    /// a list of DateFormatter formats.
    ///
    /// The old approach tried "MM/dd/yyyy" first, and DateFormatter happily matched
    /// "06/14/25" against it, reading the year as 25 AD. Every two-digit year on every
    /// bill was two thousand years in the past, which silently disabled the date rules.
    /// Reordering the formats doesn't fix it either, since "MM/dd/yy" will just as
    /// happily read "08/20/2026" as the year 2020.
    static func extractDate(from text: String) -> Date? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        func group(_ index: Int) -> Int? {
            guard let r = Range(match.range(at: index), in: text) else { return nil }
            return Int(text[r])
        }
        guard let month = group(1), let day = group(2),
              let yearRange = Range(match.range(at: 3), in: text) else { return nil }

        let yearDigits = String(text[yearRange])
        guard let yearValue = Int(yearDigits) else { return nil }

        let year: Int
        switch yearDigits.count {
        case 4:
            year = yearValue
        case 2:
            // Standard pivot: 00-68 is this century, 69-99 is the last one.
            year = yearValue <= 68 ? 2000 + yearValue : 1900 + yearValue
        default:
            return nil   // three digits means OCR mangled it; better to have no date
        }

        guard (1...12).contains(month), (1...31).contains(day),
              (1900...2100).contains(year) else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: components)
    }

    /// Every date anywhere in the text. Used as a fallback when OCR row grouping
    /// fails to attach dates to their line items.
    static func allDates(in text: String) -> [Date] {
        matchesAll(in: text, pattern: datePattern).compactMap { extractDate(from: $0) }
    }

    static func extractQuantity(from text: String) -> Int? {
        if let qty = firstMatch(in: text, pattern: #"(?i)\b(?:qty|quantity|units?)\s*[:#]?\s*(\d{1,3})\b"#) {
            return Int(qty)
        }
        return nil
    }

    /// v7.1: the provider used to be "whatever OCR read first", which turned into
    /// nonsense when a photo carried a filename banner or other chrome above the bill.
    /// Now the first few rows are scored, and anything that doesn't read like an
    /// organisation's name is skipped.
    private static func detectProviderName(rows: [String]) -> String? {
        let allowedPunctuation = Set(" &.,'-()")
        for row in rows.prefix(10) {
            let trimmed = row.trimmingCharacters(in: .whitespaces)
            guard (4...60).contains(trimmed.count) else { continue }

            // Names don't contain amounts, dates, file paths, or UI glyphs.
            let usable = trimmed.allSatisfy { $0.isLetter || allowedPunctuation.contains($0) }
            guard usable else { continue }

            let letters = trimmed.filter { $0.isLetter }.count
            guard letters >= 4, Double(letters) / Double(trimmed.count) >= 0.7 else { continue }

            // A document title is not the provider's name.
            let lowered = trimmed.lowercased()
            if ReferenceData.documentTitleTerms.contains(where: { lowered.contains($0) }) { continue }
            if isTableHeaderRow(lowered) { continue }

            return trimmed
        }
        // v8: falling back to "whatever was on the first row" used to put a table
        // header in the title bar when a continuation page carried no provider name.
        // Better to admit we don't know: the UI then says "Scanned bill".
        return nil
    }

    /// A column header row, such as "DATE DESCRIPTION CODE QTY AMOUNT".
    private static func isTableHeaderRow(_ lowered: String) -> Bool {
        let headers = ["date", "description", "code", "qty", "quantity", "amount",
                       "charges", "units", "service", "rev", "hcpcs", "cpt"]
        let hits = headers.filter { lowered.contains($0) }.count
        return hits >= 3
    }

    private static func detectStatementDate(rows: [String]) -> Date? {
        for row in rows {
            let lowered = row.lowercased()
            if lowered.contains("statement date") || lowered.contains("bill date") || lowered.contains("date of statement") {
                if let date = extractDate(from: row) { return date }
            }
        }
        return nil
    }

    // MARK: Regex helpers

    private static func matches(_ text: String, any keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func matchesAll(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let groupRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        return Range(groupRange, in: text).map { String(text[$0]) }
    }
}

// MARK: - Built-in sample bill (for demo / simulator, where there's no camera)

enum SampleBill {
    static let text = """
    CITY GENERAL HOSPITAL
    EMERGENCY DEPARTMENT STATEMENT
    Account Number: BH-204981
    Statement Date 08/15/2026
    08/02/2026 EMERGENCY DEPT VISIT LEVEL 3 99283 $390.00
    08/02/2026 ECG ROUTINE 12 LEADS 93000 $150.00
    08/02/2026 ECG ROUTINE 12 LEADS 93000 $150.00
    08/02/2026 COMPREHEN METABOLIC PANEL 80053 $120.00
    08/02/2026 GLUCOSE BLOOD TEST 82947 $40.00
    08/02/2026 MISC SUPPLIES $340.00
    Total Charges $1,040.00
    Amount Due $1,040.00
    """
}
