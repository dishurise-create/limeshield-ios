// End-to-end check on the rendered test bills: Vision OCR (same settings as
// OCRService) → BillParser → RulesEngine. Run with testbills/run_ocr_tests.sh
import Foundation
import CoreGraphics
import ImageIO
import Vision

struct OCRWord: Sendable { let text: String; let box: CGRect }

func ocr(_ path: String) throws -> [OCRWord] {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw NSError(domain: path, code: 1) }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return (request.results ?? []).compactMap { obs in
        obs.topCandidates(1).first.map { OCRWord(text: $0.string, box: obs.boundingBox) }
    }
}

// Rule ids each bill must produce, and ids it must not.
let expectations: [(file: String, must: [String], mustNot: [String], noRed: Bool)] = [
    ("bill-A-errors.png",     ["duplicate"],     [],                 false),
    ("bill-B-clean.png",      [],                ["math", "duplicate"], true),
    ("bill-C-unitemized.png", ["not_itemized"],  ["math"],           true),
    ("bill-D-eob.png",        ["eob"],           [],                 true),
    ("bill-E-outlier.png",    ["outlier"],       ["math"],           false),
    ("bill-F-newrules.png",   ["after_hours_fee", "drug_markup", "timely_filing"],              ["math"],           false),
]

var failures = 0
let dir = CommandLine.arguments[1]
for e in expectations {
    let bill = BillParser.parse(pages: [try ocr(dir + "/" + e.file)])
    let issues = RulesEngine.analyze(bill)
    let ids = Set(issues.map(\.ruleID))
    var problems: [String] = []
    for id in e.must where !ids.contains(id) { problems.append("missing \(id)") }
    for id in e.mustNot where ids.contains(id) { problems.append("unexpected \(id)") }
    if e.noRed, let red = issues.first(where: { $0.severity == .likelyError }) { problems.append("red \(red.ruleID)") }
    if !problems.isEmpty { failures += 1 }
    print(problems.isEmpty ? "ok  " : "FAIL", e.file, "lines=\(bill.chargeLines.count)",
          "total=\(bill.totals.totalCharges.map { String($0) } ?? "-")", issues.map(\.ruleID).sorted(),
          problems.isEmpty ? "" : "  <- \(problems)")
}
exit(failures == 0 ? 0 : 1)
