# Lime Shield, App Store listing copy

Paste each block into the matching field in App Store Connect.
Character limits are Apple's, and every field below is within them.

---

## App Name (30 max)

```
Lime Shield
```

## Subtitle (30 max)

```
Check medical bills privately
```

29 characters. This is the line under the name in search results, so it carries
the two things that matter: what it does, and the thing no competitor says.

---

## Promotional Text (170 max)

Editable any time without submitting a new build, so it is the one field you can
change after release.

```
Most medical bills contain errors, and nobody checks them. Lime Shield reads yours on your phone and tells you exactly what to question. Nothing is ever uploaded.
```

---

## Keywords (100 max, comma separated, no spaces)

```
medical bill,hospital,billing error,itemized,healthcare,insurance,EOB,overcharge,dispute,scanner
```

Do not repeat words already in the name or subtitle. Apple indexes those
separately, so spending characters on them is wasted.

---

## Description (4000 max)

```
Medical bills are confusing on purpose, and almost nobody checks them line by line. Lime Shield does that for you, on your phone, in seconds.

Photograph a bill and Lime Shield reads it, checks every charge against 46 common billing problems, and tells you plainly what is worth questioning and what to say when you ask.

YOUR BILL NEVER LEAVES YOUR PHONE

This is the part that makes Lime Shield different. There is no server. Your bill is photographed, read, and analysed entirely on your device using Apple's built-in text recognition. Nothing is uploaded, no account is required, and nobody can read your medical information through this app, including us. You can put your phone in airplane mode and Lime Shield works exactly the same.

WHAT IT CHECKS FOR

Arithmetic that does not add up, like line items summing to more than the stated total.

Duplicate charges, the same service billed twice on one day or repeated across dates.

Prices far above typical rates for the billing code used.

Over-the-counter medicine at hospital prices, and basic supplies billed on top of the room fee.

Vague lump sums like "miscellaneous supplies" with no explanation.

Lab tests billed separately from the panel that already includes them.

After-hours fees, missed appointment fees, facility fees, and interest charges.

Impossible quantities, service dates after discharge, and charges with no date at all.

Plus rights you may not know you have: itemized bills on request, protections under the No Surprises Act, financial assistance policies, and what to do when a bill arrives long after the care did.

HONEST ABOUT WHAT IT IS

Lime Shield sorts findings into three levels, and the wording is deliberate.

Likely error means the arithmetic does not work. These are the only findings stated as errors.

Worth checking means something that is commonly a mistake but can be perfectly legitimate. These are phrased as questions to ask, never as accusations.

Know your rights is background information, not a problem with your bill.

A flagged charge is not proof that anything is wrong. Lime Shield helps you ask better questions, which is usually all it takes.

THEN IT HELPS YOU ASK

Every finding comes with the exact wording to use, what the billing department is likely to say back, and how to respond. Lime Shield also writes the full review letter for you, listing each charge you flagged, ready to email or print.

If your bill is only a summary, Lime Shield writes the itemized bill request instead, because most errors are invisible until you get the detailed version.

KEEP TRACK

Add findings to a to-do list so you know what you have raised and what is still outstanding. Everything stays on your device, and deleting a scan removes it for good.

LIME SHIELD PRO

The free version includes full analysis. Pro adds unlimited scans and unlimited letters for a monthly subscription. Privacy is identical either way, because there is nothing to change: your bills were never leaving your phone in the first place.

Lime Shield is an informational tool. It does not provide legal, medical, or financial advice, and using it does not create any professional relationship. Reference prices are broad national ballparks, not your plan's negotiated rates. Always check findings against the bill itself.
```

---

## Category

Primary: **Finance**
Secondary: **Medical**

Finance first is deliberate. Apps in the Medical category get additional review
scrutiny around clinical claims, and Lime Shield makes none. It is a tool about
money that happens to involve healthcare paperwork, and reviewers read it that
way.

---

## URLs

Privacy Policy URL:
```
https://dishurise-create.github.io/limeshield/privacy.html
```

Support URL:
```
https://dishurise-create.github.io/limeshield/support.html
```

---

## App Review Notes

```
Lime Shield analyses medical bills entirely on-device. No account is required
and no network connection is needed to use any feature.

TO TEST WITHOUT A REAL BILL:
On the home screen, tap "Sample". This loads a built-in example bill and runs
the full analysis, so no medical document is needed to review the app.

TO TEST THE SUBSCRIPTION:
Tap the Premium tab in the bottom bar. Free users receive 2 scans, after which
the Scan button also opens this paywall.

PRIVACY:
Bills are read using Apple's Vision framework and analysed by rules bundled in
the app. Nothing is transmitted. The only network calls the app makes are to
RevenueCat for subscription status.

DISCLAIMERS:
The app does not provide medical, legal, or financial advice. Findings are
presented as items worth questioning, not as proof of error, and the Learn tab
carries full disclaimers.
```

---

## App Privacy questionnaire

Answer YES to "do you or your third-party partners collect data from this app",
then declare exactly one data type.

**Purchases → Purchase History**
- Linked to the user's identity: **No**. Lime Shield never sets a custom app
  user ID, so RevenueCat only ever sees an anonymous identifier.
- Used for tracking: **No**. No advertising SDKs, no cross-app tracking.
- Purposes: **App Functionality** and **Analytics**. App Functionality covers
  receipt validation, Analytics covers the subscriber charts in RevenueCat's
  own dashboard.

**Everything else: not collected.** No contact info, no identifiers, no health
data, no usage data, no diagnostics, no location.

Two things worth understanding rather than just copying:

*Why not Identifiers.* RevenueCat's own guidance says to declare Identifiers
only if you set custom app user IDs or use an advertising integration such as
IDFA. Lime Shield does neither, so declaring it would overstate what you
collect. An earlier draft of this file said to declare Device ID. That was
wrong, and over-declaring is not automatically the safe choice: the label is
what users read to decide whether to trust you.

*Why Sign in with Apple needs no declaration.* The identifier is stored on the
device and never transmitted anywhere. Apple's questionnaire is about data that
leaves the device.

Do not answer "no data collected". You ship the RevenueCat SDK, and a reviewer
comparing your declaration against the binary would catch it.
