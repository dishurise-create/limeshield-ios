import SwiftUI

/// Lets the user correct what the scan read.
///
/// OCR will always misread something eventually, and the person holding the bill can
/// see the truth that the camera couldn't. Correcting a figure here re-runs all the
/// rules against the corrected data, so a bad scan no longer means a bad result.
struct EditBillView: View {
    @State private var draft: Bill
    private let onSave: (Bill) -> Void
    @Environment(\.dismiss) private var dismiss

    init(bill: Bill, onSave: @escaping (Bill) -> Void) {
        _draft = State(initialValue: bill)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Correct anything the scan got wrong, and add anything it missed. The findings are recalculated when you save.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Bill details") {
                    LabeledTextField(label: "Provider", text: providerBinding)
                    LabeledTextField(label: "Account", text: accountBinding)
                }

                Section("Totals") {
                    AmountField(label: "Total charges", value: $draft.totals.totalCharges)
                    AmountField(label: "Amount due", value: $draft.totals.amountDue)
                    AmountField(label: "Previous balance", value: $draft.totals.previousBalance)
                    AmountField(label: "Payments", value: $draft.totals.payments)
                    AmountField(label: "Adjustments", value: $draft.totals.adjustments)
                }

                Section {
                    ForEach($draft.lines) { $line in
                        NavigationLink {
                            LineEditorView(line: $line)
                        } label: {
                            lineRow(line)
                        }
                    }
                    .onDelete { draft.lines.remove(atOffsets: $0) }

                    Button {
                        draft.lines.append(BillLine(raw: "", desc: "New charge", amount: nil))
                    } label: {
                        Label("Add a charge", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Charges")
                } footer: {
                    Text("Swipe a charge to delete it. Tap one to edit its description, amount, billing code, date, or quantity.")
                }
            }
            .navigationTitle("Edit scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Rows

    private func lineRow(_ line: BillLine) -> some View {
        let amount = line.amount == nil ? "no amount" : line.amount!.usd
        return HStack {
            Text(line.desc.isEmpty ? "Untitled charge" : line.desc)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(amount)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Optional-string bindings

    private var providerBinding: Binding<String> {
        Binding(get: { draft.providerName ?? "" },
                set: { draft.providerName = $0.isEmpty ? nil : $0 })
    }

    private var accountBinding: Binding<String> {
        Binding(get: { draft.accountNumber ?? "" },
                set: { draft.accountNumber = $0.isEmpty ? nil : $0 })
    }
}

// MARK: - Single line editor

struct LineEditorView: View {
    @Binding var line: BillLine

    var body: some View {
        List {
            Section("Description") {
                TextField("Description", text: $line.desc, axis: .vertical)
            }
            Section("Amount") {
                AmountField(label: "Amount", value: $line.amount)
            }
            Section("Billing code") {
                LabeledTextField(label: "Code", text: codeBinding)
            }
            Section("Quantity") {
                LabeledTextField(label: "Quantity", text: quantityBinding, keyboard: .numberPad)
            }
            Section("Date of service") {
                if line.date == nil {
                    Button("Add a date") { line.date = Date() }
                } else {
                    DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    Button("Remove date", role: .destructive) { line.date = nil }
                }
            }
        }
        .navigationTitle("Edit charge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var codeBinding: Binding<String> {
        Binding(get: { line.code ?? "" },
                set: { line.code = $0.isEmpty ? nil : $0 })
    }

    private var quantityBinding: Binding<String> {
        Binding(get: {
            guard let quantity = line.quantity else { return "" }
            return "\(quantity)"
        }, set: {
            line.quantity = Int($0)
        })
    }

    private var dateBinding: Binding<Date> {
        Binding(get: { line.date ?? Date() },
                set: { line.date = $0 })
    }
}

// MARK: - Field building blocks

struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            TextField("none", text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
        }
    }
}

/// Edits an optional currency value. Empty means "not on the bill", which the rules
/// treat differently from zero, so the distinction is preserved.
struct AmountField: View {
    let label: String
    @Binding var value: Double?

    private var text: Binding<String> {
        Binding(get: {
            guard let value else { return "" }
            if value == value.rounded() { return "\(Int(value))" }
            return String(format: "%.2f", value)
        }, set: { newValue in
            let cleaned = newValue.filter { $0.isNumber || $0 == "." || $0 == "-" }
            if cleaned.isEmpty {
                value = nil
            } else {
                value = Double(cleaned)
            }
        })
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            Text("$").foregroundStyle(.secondary)
            TextField("none", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .frame(maxWidth: 130)
        }
    }
}
