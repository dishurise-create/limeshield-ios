# Lime Shield demo video script (target 1:50, hard limit 2:00)

Uses the City General Hospital test bill (testbills/bill-A-errors.png).
Verified: the app finds, every time,
  - Line items add up to more than the stated total ($1,190 vs $1,040), red
  - Possible duplicate charge: ECG ROUTINE 12 LEADS, twice
  - Large vague charge: MISC SUPPLIES $340
  - Tests usually billed as one panel: glucose 82947 with metabolic panel 80053
  - Ask about financial assistance, and no insurance payment shown

Before recording:
- Get the bill in front of the camera. Best: open bill-A-errors.png full screen
  on your Mac (or print it). Backup: AirDrop it to your iPhone and use Photos.
- Scanning uses one free scan. Do one practice scan first; you have two.
- iPhone: Do Not Disturb on. Control Centre: long-press Screen Recording,
  Microphone ON. Open Lime Shield, start recording, wait 2 seconds.

---

## 0:00 to 0:12, the problem
SCREEN: Lime Shield home screen.

SAY:
"Medical bills are confusing, and mistakes like duplicate charges or totals
that don't add up are easy to miss. I'm a tenth grader, and I built Lime
Shield so anyone can check their bill before they pay."

## 0:12 to 0:30, scan
TAP: Scan a bill. Point the phone at the bill until it snaps, tap Save.
(Backup: tap Photos and pick the bill.)

SAY:
"Here's an emergency room bill. Lime Shield reads it with Apple's on-device
text recognition. Nothing is uploaded, and it even works in airplane mode.
Then it checks every charge against 46 known billing problems."

## 0:30 to 1:00, results
SCREEN: results. Pause on the top, then scroll slowly.

SAY:
"The line items add up to 1,190 dollars, but the bill says 1,040. That's the
only kind of finding it calls an error, because it's arithmetic. The same ECG
is charged twice. There's 340 dollars of miscellaneous supplies with no
detail. And a glucose test billed on its own, even though it's normally part
of the metabolic panel on the line above. Everything except the math is
phrased as a question, because I'd rather stay quiet than accuse an honest
hospital."

## 1:00 to 1:15, what to say
TAP: Possible duplicate charge. Scroll a little. TAP: back arrow.

SAY:
"For each one it tells you exactly what to ask billing, and what to say if
they push back."

## 1:15 to 1:32, the letter
SCROLL to the bottom, TAP: Generate review letter. Scroll the letter a little.

SAY:
"Then it writes the letter for you, with your account number and every item
to verify before you pay."
TAP: Done.

## 1:32 to 1:50, monetization
TAP: Premium tab. Do NOT tap the subscribe button.

SAY:
"Two scans and two letters are free. Lime Shield Pro is 2.99 a month for
unlimited scans and letters, powered by RevenueCat. Lime Shield is live on the
App Store now."

STOP recording.

---

After recording:
- Photos: Edit, trim the start and end. Check it's under 2:00.
- YouTube: upload, Visibility Unlisted, paste the link into Devpost.
