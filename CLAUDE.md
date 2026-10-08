# Lime Shield

iOS app that scans medical bills and flags billing problems. Everything runs
on device. Built by an 11th grader for the RevenueCat Shipaton 2026.

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
  `limeshield_pro_monthly`, 2.99/month. Free tier is 2 scans. The paywall
  shows a free trial only when the product has one AND the customer is
  eligible (`freeTrial`). Debug builds: launch with `-previewFreeTrial` to see
  the trial paywall.

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

`testbills/run_parser_tests.sh` compiles the app's real `BillParser`, `Models`,
`ReferenceData` and `RulesEngine*` sources on the Mac together with the
fixtures in `testbills/ParserTests/main.swift`, and runs them. Each fixture has
a known answer, and most encode one of the parser rules above. Run it after
any parser or rules change, and add a fixture for every new bug found.

```
testbills/run_parser_tests.sh
```

It replaced `simulate_v8.py`, a Python port that was lost in the move from
chat. Compiling the real sources means the tests cannot drift from the app.
`testbills/*.png` are the rendered test bills from `make_bills.py`.

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
- LIVE: version 1.0 (build 3) released on the App Store 2026-09-30,
  https://apps.apple.com/us/app/lime-shield/id6811397021
  Build 2 was rejected; build 3 was resubmitted 2026-09-24 with a reply to
  App Review (`app-review-reply-2.1b.txt`).
- Next: version 1.0.1 (build 4), not yet uploaded. Adds free-trial wording to
  the paywall, the refund request letter, and free-tier counts that survive
  a reinstall. The 1-week introductory offer must be created in App Store
  Connect to start when 1.0.1 goes live, not before: the live 1.0 paywall
  doesn't mention trials.
- Shipaton deadline: 2026-09-30 23:45 PT. The app had to be live by then.
  Winners announced 2026-10-22. Entered in Next Gen (the only category open
  to minors): needs the public repo, a student email and parental consent.
- Public repo (MIT): https://github.com/dishurise-create/limeshield-ios.
  Devpost project: https://devpost.com/software/lime-shield
- Judges' free month: offer code LIMESHIELDJUDGE (500 uses, no auto-renew,
  expires 2026-11-30).
- Checked 2026-09-24 and all fine: Paid Apps Agreement, banking and W-9
  Active; Pro Monthly Ready for Review, all regions; RevenueCat IAP key valid;
  `pro` entitlement attached to the App Store product. So the 2.1(b)
  rejection was most likely a sandbox glitch, not configuration.
- Rejected under 2.1(b) on 2026-09-24: reviewer on iPad Air (M3), iPadOS 27
  saw "The product is not available for purchase." on the paywall.
- Rejected once under 3.1.2 because the App Description lacked a link to
  Apple's standard EULA. Fixed in metadata, no code change.
- Privacy policy and support pages are static HTML served from GitHub Pages
  at dishurise-create.github.io/limeshield/.

## Known open work

- Reference prices are broad national ballparks with no citations. The app
  says so, but sourced figures would be better.
- MMDDYY dates ("030126") on hospital statements aren't parsed. The
  no-service-dates rule stays silent for them instead. Parsing them safely
  needs a way to tell them from reference numbers.

## Free tier

2 free scans and 2 free letters. The counts live in the Keychain
(`FreeTierStore`) as well as UserDefaults, and the larger wins, so deleting
and reinstalling doesn't hand out fresh free scans. Device-only, never synced.
Don't move the counts back to UserDefaults alone.

## Letters

`BillAnalysis.letterKind` picks the letter: `itemizedRequest` (unitemized
bill), `review` (anything actionable), `refund` (only a credit balance, and
the user hasn't dismissed it). A review letter on a bill that is also in
credit gets an extra paragraph asking for the refund. Every letter asks and
never accuses; the refund letter says "if this is correct". The generator is
compiled into the parser tests.

## Resolved 2026-09-24 (don't reintroduce)

- History used to show the findings saved at scan time forever, so findings
  a later version withdrew (the red Stanford/Granite State ones) survived.
  `AnalysisStore.load()` now re-runs today's rules on each saved bill.
- Review letters have their own allowance (2 free, tied to the bill), so a
  free user's last scan doesn't lock them out of its letter.
- Insurer EOBs and multi-bill scans don't use up a free scan.
- Every rule has a fixture that triggers it. `quantity_math` could never fire
  and `already_paid` was red on wording; both fixed.
- Sample bills don't count toward "Flagged so far".
