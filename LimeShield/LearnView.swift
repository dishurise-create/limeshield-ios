import SwiftUI

struct LearnView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            List {
                Section("How it works") {
                    step(1, "Get the itemized bill", "Errors are invisible on a summary.")
                    step(2, "Scan it", "Good light, phone flat above the page.")
                    step(3, "Read the findings", "Tap any one to see the exact lines.")
                    step(4, "Send the letter", "Asks billing to verify what you flagged.")
                }

                Section("What the labels mean") {
                    meaning(.likelyError, "Arithmetic that doesn't add up.")
                    meaning(.worthChecking, "Often a mistake, but can be legitimate.")
                    meaning(.knowYourRights, "Protections you have, not a problem.")
                }

                Section {
                    ForEach(RuleCatalog.groups) { group in
                        DisclosureGroup {
                            ForEach(group.items, id: \.self) { item in
                                Text(item)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 1)
                            }
                        } label: {
                            HStack {
                                Text(group.title).font(.callout.weight(.medium))
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("What it checks")
                } footer: {
                    Text("\(RulesEngine.ruleCount) checks, all on your device.")
                }

                Section("Privacy") {
                    bullet("lock.shield.fill", "Your bills never leave this phone.",
                           "No server, no analytics, no account needed.")
                    bullet("internaldrive", "Scans are stored only in this app.",
                           "Deleting a scan removes it for good.")
                }

                Section {
                    DisclosureGroup("Important disclaimers") {
                        ForEach(RuleCatalog.disclaimers) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.callout.weight(.semibold))
                                Text(item.detail).font(.callout).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .font(.callout.weight(.medium))
                }

                Section("About") {
                    Text("Built so anyone can read a medical bill the way a billing specialist would, without giving up their privacy.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Learn")
        }
    }

    // MARK: Rows

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Circle().fill(settings.accentColor.opacity(0.16)))
                .foregroundStyle(settings.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func meaning(_ severity: IssueSeverity, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Pill(text: severity.title, color: severity.color)
                .frame(width: 116, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(settings.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Catalog

/// The rule list and disclaimers, kept out of the view so the Learn screen stays
/// a layout file rather than a wall of strings.
enum RuleCatalog {
    struct Group: Identifiable {
        let id = UUID()
        let title: String
        let items: [String]
    }

    /// A struct rather than a tuple: ForEach needs something Identifiable, and Swift
    /// has no key paths into tuple labels.
    struct Note: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    static let groups: [Group] = [
        Group(title: "Arithmetic", items: [
            "Line items adding up to more than the stated total",
            "Statement balances that don't reconcile",
            "An amount due larger than the charges listed",
            "Payments recorded above the total charged",
            "Credit balances the provider may owe you",
        ]),
        Group(title: "Charges that repeat", items: [
            "The same service billed twice on one day",
            "The same charge appearing on several dates",
            "Two separate visit charges for a single day",
        ]),
        Group(title: "Pricing", items: [
            "Charges far above typical rates for the code",
            "Over-the-counter medicine at hospital prices",
            "Basic supplies billed on top of the room fee",
            "Vague lump sums like \"miscellaneous supplies\"",
        ]),
        Group(title: "How it was coded", items: [
            "Lab tests billed apart from the panel that includes them",
            "The highest-intensity visit code",
            "Preventive care arriving with a balance owing",
            "Vaccines and their administration fees",
            "An assistant surgeon billed separately",
        ]),
        Group(title: "Fees and add-ons", items: [
            "After-hours and special service surcharges",
            "Missed or cancelled appointment fees",
            "Interest, late fees, and admin charges",
            "Facility fees, including more than one on a bill",
            "Facility fees added to an ordinary office visit",
            "Trauma team activation fees",
        ]),
        Group(title: "Big-ticket items", items: [
            "Large anesthesia charges billed by time",
            "Video visits billed at in-person rates",
            "Ambulance transport and its coverage gap",
            "COVID testing charges",
        ]),
        Group(title: "Errors in the data", items: [
            "Service dates after the statement was issued",
            "Charges dated after you were discharged",
            "Impossible quantities on daily charges",
            "Quantity and unit price that don't multiply out",
            "Adjustments larger than the charges",
            "A bill marked paid that still asks for money",
            "Charges with no date of service at all",
            "Two different bills scanned as one",
        ]),
        Group(title: "Your rights", items: [
            "Bills that aren't itemized",
            "Insurance EOBs mistaken for bills",
            "Possible surprise bills under the No Surprises Act",
            "Observation status billed as outpatient care",
            "Bills arriving long after the care was given",
            "Collection pressure on a disputed bill",
            "Financial assistance you were never told about",
            "Bills with no insurance payment applied",
            "Out-of-network care outside an emergency",
            "Estimates mistaken for bills",
            "Self-pay bills with no discount applied",
            "Newborn charges billed as a separate patient",
        ]),
    ]

    static let disclaimers: [Note] = [
        Note(title: "Not advice",
             detail: "An informational tool only. No legal, medical, financial or insurance advice, and no professional relationship."),
        Note(title: "Starting points, not verdicts",
             detail: "A flagged item is worth asking about. It is not proof anything is wrong, and a charge can be correct even when highlighted."),
        Note(title: "Reference prices are rough",
             detail: "Broad national ballparks, not your plan's negotiated rates. Prices vary widely by region, facility and insurer."),
        Note(title: "Scanning is imperfect",
             detail: "Text is read from photographs. Treat an empty result as nothing detected, not nothing wrong."),
        Note(title: "Coverage rules vary",
             detail: "Protections depend on your plan, state and provider. Confirm anything you rely on with your insurer."),
    ]
}
