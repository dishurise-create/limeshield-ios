# Lime Shield

iOS app that scans medical bills and flags billing problems. Everything runs
on device. Built by a 10th grader for the RevenueCat Shipaton 2026.

## Layout

- `LimeShield.xcodeproj` — Xcode project, at the repo root.
- `LimeShield/` — all Swift sources, flat, no groups.
- `social/` — marketing graphics and the Python scripts that render them.
- `devpost-entry.md`, `app-review-reply-short.txt`, `LimeShield-ship-checklist.pdf`
  — submission material, not code.

## Architecture

SwiftUI, iOS 17 minimum, iPhone only, portrait only.

The pipeline is: `OCRService` (Vision) → `BillParser` → `RulesEngine` → views.

- `OCRService.swift` — `VNRecognizeTextRequest`, then groups recognised words
  into rows by vertical position. Vision's y origin is bottom-left.
- `BillParser.swift` — turns rows into a `Bill`. This is the most carefully
  written file in the project. See the parser rules below before touching it.
- `RulesEngine.swift`, `RulesEngineExtended.swift`, `RulesEngineMore.swift` —
  46 checks across 8 categories. Plain Swift, no model, no network.
- `Models.swift` — `Bill`, `Issue`, `DocumentKind`, `AnalysisStore`.
- `PurchaseManager.swift` — RevenueCat. Entitlement id `pro`, product
  `limeshield_pro_monthly`, 2.99/month. Free tier is 2 scans.

## Parser rules, do not regress these

These were all real bugs found by testing against real hospital statements.
The math rule was wrong 4 times out of 5 before this work.

1. Summary and total rows are identified and excluded before anything else.
   A "total" row is never a line item.
2. Non-charge keywords (payment, adjustment, credit, copay, deductible...)
   are matched with word boundaries. "unpaid" must not match "paid".
3. Non-charge keywords are only checked against the text BEFORE the first
   amount on the row, via `descriptionPart`. Otherwise a "Coinsurance" column
   header disqualifies the charge next to it.
4. The amount regex must handle amounts without thousands separators.
   It once truncated `1284.00` to `284.00`.
5. Rows with two or more money columns set `hasAmbiguousAmountRows`, and
   every total-dependent rule goes silent when totals are unreliable.
6. `documentKind` splits insurer EOBs (stop, the numbers are not a bill) from
   provider itemizations (analyse normally).

The governing principle: a rule that stays silent beats a rule that accuses an
honest provider. Only arithmetic findings are allowed to use the word "error".
Everything else is phrased as a question.

## Verification

`testbills/simulate_v8.py` is a Python port of the classification logic with
fixtures whose answers are known. Run it after any parser change. It has
already caught two regressions that would otherwise have shipped.

```
python3 testbills/simulate_v8.py
```

## Conventions

- Every file that declares an `ObservableObject` needs an explicit
  `import Combine`. Newer Xcode no longer re-exports it through SwiftUI, and
  omitting it produces a confusing "does not conform to ObservableObject".
- `Models.swift` also needs `import SwiftUI` for `remove(atOffsets:)`.
- There are 9 Swift 6 main-actor concurrency warnings. They are known,
  harmless, and deliberately not fixed. Do not "clean them up" without asking.
- Disclaimer strings live in `Disclaimers` in `LimeShieldApp.swift`. Shared
  view styling lives there too (`cardSurface`, `SectionLabel`, `Pill`).

## Shipping state

- Bundle `com.limeshield.LimeShield`, Apple ID 6811397021.
- Version 1.0, build 2 uploaded.
- Rejected under 2.1(b) on 2026-09-24: reviewer on iPad Air (M3), iPadOS 27
  saw "The product is not available for purchase." on the paywall.
- Rejected once under 3.1.2 because the App Description lacked a link to
  Apple's standard EULA. Fixed in metadata, no code change.
- Privacy policy and support pages are static HTML served from GitHub Pages
  at dishurise-create.github.io/limeshield/.

## Known open work

- The review letter is gated on the scan allowance rather than its own, so a
  free user who has used both scans cannot open letters for bills they already
  scanned. Worth giving letters their own small allowance.
- 16 of the 46 rules have never fired in testing. Each needs a bill that
  triggers it or it is decoration.
- Reference prices are broad national ballparks with no citations. The app
  says so, but sourced figures would be better.
- One scan in History shows a red arithmetic finding against a real Stanford
  statement. Unclear whether it predates the parser rewrite or is a surviving
  false positive. Worth checking before trusting that rule.
