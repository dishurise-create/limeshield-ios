# Lime Shield

Scan a medical bill and find out what's worth questioning before you pay.
Everything runs on the iPhone: no server, no account, nothing uploaded.

[Download on the App Store](https://apps.apple.com/us/app/lime-shield/id6811397021)

Built for the RevenueCat Shipaton 2026.

## What it does

- Reads a photographed bill with Apple's on-device text recognition (Vision).
- Checks it against 46 known billing problems: arithmetic that doesn't add
  up, duplicate charges, vague lump sums, tests normally billed as one panel,
  and more.
- Only arithmetic is ever called an error. Everything else is phrased as a
  question, so the app never accuses an honest provider.
- Tells you what to ask billing, what to say if they push back, and writes
  the review letter.
- Lime Shield Pro (unlimited scans and letters) is a subscription powered by
  RevenueCat.

## Building

Open `LimeShield.xcodeproj` in Xcode and run the `LimeShield` scheme.
iOS 17 or later, iPhone. RevenueCat is pulled in by Swift Package Manager.

## Tests

The parser and rules are tested by compiling the app's real Swift sources on
the Mac together with known-answer bills:

```
testbills/run_parser_tests.sh   # 78 fixtures, every rule triggered at least once
testbills/run_ocr_tests.sh      # rendered test bills through Vision OCR
```

## Layout

- `LimeShield/` Swift sources. Pipeline: `OCRService` → `BillParser` →
  `RulesEngine*` → views.
- `testbills/` test bills, fixtures and test runners.
- `social/` marketing and Devpost material.

## License

MIT, see [LICENSE](LICENSE).
