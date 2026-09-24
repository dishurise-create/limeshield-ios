import SwiftUI

/// Shows exactly what the parser pulled out of a scan.
///
/// Rules can only be as good as the parse behind them, and reasoning about a
/// misbehaving rule from a screenshot of its output is guesswork. This makes the
/// intermediate state visible so a wrong result can be traced to the parse or to
/// the rule, rather than argued about.
///
/// Written deliberately plainly: every value is turned into a String by a small
/// explicit function first. Chained `map`/`??` expressions inside a ViewBuilder are
/// what made the type-checker give up on the first version of this file.
struct DiagnosticsView: View {
    let bill: Bill

    // MARK: Formatting helpers

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func text(_ date: Date?) -> String {
        guard let date else { return "none" }
        return Self.dayFormatter.string(from: date)
    }

    private func text(_ value: Double?) -> String {
        guard let value else { return "not found" }
        return value.usd
    }

    private func text(_ value: Int?) -> String {
        guard let value else { return "-" }
        return "\(value)"
    }

    // MARK: Derived data

    private var lineDates: [Date] {
        var result: [Date] = []
        for line in bill.chargeLines {
            if let date = line.date { result.append(date) }
        }
        return result
    }

    private var textDates: [Date] {
        BillParser.allDates(in: bill.rawText)
    }

    private var gapDescription: String {
        guard let statement = bill.statementDate else { return "no statement date" }
        guard let earliest = lineDates.min() else { return "no line dates" }
        let days = Int(statement.timeIntervalSince(earliest) / 86_400)
        return "\(days) days"
    }

    private var rowCount: Int {
        bill.rawText.components(separatedBy: "\n").count
    }

    private var kindDescription: String {
        switch bill.kind {
        case .bill:                return "bill"
        case .insurerEOB:          return "insurer EOB"
        case .providerItemization: return "provider itemization"
        }
    }

    // MARK: Body

    var body: some View {
        List {
            Section("Document") {
                kv("Provider", bill.providerName ?? "NOT FOUND")
                kv("Account", bill.accountNumber ?? "NOT FOUND")
                kv("Statement date", bill.statementDate == nil ? "NOT FOUND" : text(bill.statementDate))
                kv("Document kind", kindDescription)
                kv("Multiple bills", bill.multipleBillsDetected == true ? "yes" : "no")
            }

            Section("Parse confidence") {
                kv("Multi-column rows", bill.hasAmbiguousAmountRows == true ? "YES" : "no")
                kv("Credit or payment lines", "\(bill.creditLineCount ?? 0)")
                kv("Math rules running", bill.mathIsReliable ? "yes" : "NO")
                kv("Totals trusted", bill.totalsAreReliable ? "yes" : "NO")
            }

            Section("Totals") {
                kv("Total charges", text(bill.totals.totalCharges))
                kv("Amount due", text(bill.totals.amountDue))
                kv("Previous balance", text(bill.totals.previousBalance))
                kv("Payments", text(bill.totals.payments))
                kv("Adjustments", text(bill.totals.adjustments))
            }

            Section("Dates") {
                kv("Charge lines", "\(bill.chargeLines.count)")
                kv("Lines with a date", "\(lineDates.count)")
                kv("Earliest line date", text(lineDates.min()))
                kv("Latest line date", text(lineDates.max()))
                kv("Dates anywhere in text", "\(textDates.count)")
                kv("Statement minus earliest", gapDescription)
            }

            Section("Parsed line items") {
                if bill.lines.isEmpty {
                    Text("none").foregroundStyle(.secondary)
                }
                ForEach(bill.lines) { line in
                    lineRow(line)
                }
            }

            Section("Raw text as read") {
                NavigationLink {
                    RawTextView(text: bill.rawText)
                } label: {
                    Label("View \(rowCount) rows", systemImage: "doc.plaintext")
                }
                ShareLink(item: report) {
                    Label("Share scan details", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Scan details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func kv(_ key: String, _ value: String) -> some View {
        let missing = value.hasPrefix("NOT")
        let valueColor: Color = missing ? .red : .secondary
        return HStack(alignment: .top) {
            Text(key).font(.callout)
            Spacer(minLength: 12)
            Text(value)
                .font(.callout.monospaced())
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }

    private func lineRow(_ line: BillLine) -> some View {
        let amount = text(line.amount)
        let code = line.code ?? "-"
        let date = text(line.date)
        let qty = text(line.quantity)
        let detail = "amt: \(amount)  code: \(code)  date: \(date)  qty: \(qty)"
        return VStack(alignment: .leading, spacing: 2) {
            Text(line.desc).font(.callout.weight(.medium))
            Text(detail)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// One block of text that can be pasted straight into a bug report.
    private var report: String {
        var out: [String] = ["LIME SHIELD SCAN DETAILS", ""]
        out.append("provider: " + (bill.providerName ?? "nil"))
        out.append("account: " + (bill.accountNumber ?? "nil"))
        out.append("statementDate: " + text(bill.statementDate))
        out.append("documentKind: \(kindDescription)")
        out.append("ambiguousAmountRows: \(bill.hasAmbiguousAmountRows == true)")
        out.append("creditLines: \(bill.creditLineCount ?? 0)")
        out.append("mathIsReliable: \(bill.mathIsReliable)")
        out.append("totalCharges: " + text(bill.totals.totalCharges))
        out.append("amountDue: " + text(bill.totals.amountDue))
        out.append("payments: " + text(bill.totals.payments))
        out.append("adjustments: " + text(bill.totals.adjustments))
        out.append("chargeLines: \(bill.chargeLines.count), withDate: \(lineDates.count)")

        var textDateStrings: [String] = []
        for date in textDates { textDateStrings.append(text(date)) }
        out.append("textDates: " + textDateStrings.joined(separator: ", "))
        out.append("gap: " + gapDescription)
        out.append("")

        out.append("LINES:")
        for line in bill.lines {
            let amount = text(line.amount)
            let code = line.code ?? "nil"
            let date = text(line.date)
            let qty = text(line.quantity)
            out.append("  desc=\(line.desc) | amt=\(amount) | code=\(code) | date=\(date) | qty=\(qty)")
        }
        out.append("")
        out.append("RAW TEXT:")
        out.append(bill.rawText)
        return out.joined(separator: "\n")
    }
}

struct RawTextView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "(empty)" : text)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle("Raw text")
        .navigationBarTitleDisplayMode(.inline)
    }
}
