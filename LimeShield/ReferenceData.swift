import Foundation

/// Reference data for the rules engine.
/// Benchmarks are ROUGH typical billed charges (national ballpark, USD) used only to
/// spot extreme outliers (>= 5x). They are reference points, not authoritative prices.
enum ReferenceData {

    static let benchmarks: [String: Double] = [
        // Office visits (established / new)
        "99211": 75, "99212": 120, "99213": 180, "99214": 250, "99215": 350,
        "99202": 150, "99203": 300, "99204": 450, "99205": 600,
        // Emergency department
        "99281": 200, "99282": 400, "99283": 700, "99284": 1200, "99285": 2000,
        // Labs
        "80048": 80, "80053": 120, "85025": 85, "80061": 110, "84443": 120,
        "81001": 60, "36415": 25, "82947": 40, "84132": 35, "82565": 40,
        "82465": 35, "84478": 35, "83718": 40, "85027": 60, "85004": 45,
        // Imaging
        "71046": 250, "70450": 1700, "74177": 2500, "72148": 2500,
        // Cardio / vaccines
        "93000": 150, "90686": 40, "90471": 40,
    ]

    static let outlierMultiplier = 5.0

    static let highIntensityCodes: Set<String> = [
        "99285", "99215", "99205", "99233", "99223", "99291",
    ]

    /// (panel code, component codes, human name)
    static let bundlePairs: [(panel: String, components: Set<String>, name: String)] = [
        ("80053", ["80048", "82947", "84132", "82565"], "comprehensive metabolic panel"),
        ("80061", ["82465", "84478", "83718"], "lipid panel"),
        ("85025", ["85027", "85004"], "complete blood count"),
    ]

    static let vagueTerms = [
        "miscellaneous", "misc", "supplies", "other charges", "service charge", "general",
    ]
    static let vagueThreshold = 150.0

    static let supplyTerms = [
        "gloves", "gown", "mask kit", "thermometer", "toothbrush",
        "admission kit", "warming blanket",
    ]

    static let dayBasedTerms = ["room", "bed", "daily", "per day", "semi-priv"]

    static let eobMarkers = ["this is not a bill", "explanation of benefits"]
    static let surpriseMarkers = ["out-of-network", "out of network"]
    static let erMarkers = ["emergency", " er ", "99281", "99282", "99283", "99284", "99285"]

    static let mathTolerance = 1.00
    static let notItemizedMinDue = 100.0
    static let maxIssuesShown = 15

    // MARK: - v7 rule data

    /// Evaluation & management visit codes. Two on one day is unusual.
    static let visitCodes: Set<String> = [
        "99202", "99203", "99204", "99205",
        "99211", "99212", "99213", "99214", "99215",
        "99281", "99282", "99283", "99284", "99285",
    ]

    /// Drugs a patient could buy over the counter for a few dollars.
    static let selfAdministeredDrugs = [
        "acetaminophen", "tylenol", "ibuprofen", "motrin", "advil", "aspirin",
        "antacid", "tums", "docusate", "colace", "melatonin", "senna",
        "milk of magnesia", "ranitidine", "famotidine", "pepcid",
    ]
    static let drugMarkupThreshold = 10.0

    static let assistantSurgeonTerms = [
        "assistant surgeon", "asst surgeon", "co-surgeon", "cosurgeon",
        "surgical assistant", "modifier 80", "modifier 82",
    ]

    static let preventiveTerms = [
        "preventive", "preventative", "annual wellness", "wellness visit",
        "well woman", "well child", "well-child", "routine physical",
        "annual physical", "screening mammogram", "screening colonoscopy",
    ]

    static let vaccineTerms = [
        "vaccine", "vaccination", "immunization", "flu shot", "influenza vac",
    ]
    static let vaccineCodes: Set<String> = ["90471", "90472", "90686", "90688"]

    static let afterHoursTerms = [
        "after hours", "after-hours", "weekend fee", "holiday fee",
        "emergency service fee", "special service",
    ]

    static let missedAppointmentTerms = [
        "no show", "no-show", "missed appointment", "cancellation fee",
        "late cancel",
    ]

    /// v7.1: "service fee" was removed. It matched "AFTER HOURS SERVICE FEE" and
    /// double-flagged the same line under two rules.
    static let interestTerms = [
        "interest", "late fee", "late charge", "finance charge",
        "rebilling fee", "convenience fee", "billing fee", "statement fee",
    ]

    static let observationTerms = ["observation status", "observation care", "obs unit", "observation hour"]

    static let collectionsTerms = [
        "past due", "delinquent", "collection agency", "sent to collections",
        "final notice", "pre-collection",
    ]

    static let financialAssistanceTerms = [
        "financial assistance", "charity care", "payment plan", "financial aid",
    ]

    /// A bill this large is worth asking about assistance and payment plans.
    static let financialAssistanceMinDue = 1000.0

    /// Statements this long after the service date are worth questioning.
    static let timelyFilingDays = 365.0

    // MARK: - v8 rule data (rules 31-45)

    static let facilityFeeTerms = ["facility fee", "facility charge", "hospital fee", "clinic fee"]
    static let traumaTerms = ["trauma team", "trauma activation", "trauma alert", "trauma response"]
    static let telehealthTerms = ["telehealth", "telemedicine", "virtual visit", "video visit", "e-visit"]
    static let ambulanceTerms = ["ambulance", "ems transport", "medical transport", "paramedic"]
    static let covidTerms = ["covid", "sars-cov-2", "coronavirus"]
    static let testTerms = ["test", "screen", "swab", "pcr", "antigen"]
    static let outOfNetworkTerms = ["out-of-network", "out of network", "non-participating", "nonparticipating"]
    static let estimateTerms = ["good faith estimate", "this is an estimate", "estimated charges", "cost estimate", "pre-service estimate"]
    static let paidInFullTerms = ["paid in full", "no balance due", "balance: $0.00", "zero balance"]
    static let dischargeTerms = ["discharge date", "discharged on", "date of discharge"]
    static let selfPayTerms = ["self-pay", "self pay", "uninsured", "no insurance on file"]
    static let discountTerms = ["discount", "self-pay rate", "prompt pay", "adjustment"]
    static let newbornTerms = ["newborn", "nursery", "neonatal", "baby boy", "baby girl"]

    /// Anesthesia is billed in time units, so a very large figure is worth a look.
    static let anesthesiaHighAmount = 3000.0
    /// A telehealth visit costing this much is worth comparing to the in-person rate.
    static let telehealthHighAmount = 250.0
    /// Trauma activation fees start around here and climb into five figures.
    static let traumaNotableAmount = 1000.0

    /// Rows that are document titles rather than the provider's name.
    static let documentTitleTerms = [
        "statement", "invoice", "explanation of benefits", "summary of account",
        "past due", "final notice", "billing summary", "account summary",
        "this is not a bill",
    ]
}
