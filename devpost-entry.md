# Lime Shield

## Tagline

Check a medical bill for billing problems in seconds, entirely on your phone. Nothing is ever uploaded.

---

## Inspiration

A medical bill arrives as a wall of codes, abbreviations and totals that do not obviously add up. Almost nobody reads one line by line, because almost nobody knows what a line is supposed to look like. So people either pay it or panic about it.

The people hurt most by that are the ones who cannot absorb a surprise charge. They are also the least likely to have someone to ask. Billing advocates exist, but they cost money, and the people who need one most are the people who cannot hire one.

The other half of the idea came from what happens when you try to solve this with software. Every tool that reads your bill wants you to upload it first. A medical bill carries your name, your provider, your dates of service and your diagnosis codes. Handing that to a server to be told your arithmetic is off is a bad trade, and it is the reason a lot of people never try.

So the constraint came first: if this app cannot work without ever uploading a bill, it should not exist.

## What it does

Photograph a medical bill. Lime Shield reads it using Apple's on-device text recognition, checks every charge against 46 known billing problems, and tells you in plain language which items are worth questioning and what to say when you call.

The checks span eight categories: arithmetic that does not reconcile, duplicate charges, prices far above typical rates for the billing code, retail items at hospital prices, vague lump sums, unbundled lab panels, questionable fees, and impossible dates or quantities.

Findings are sorted into three tiers, and the wording of each tier is deliberate.

Likely error means the arithmetic does not work. These are the only findings stated as errors.

Worth checking means something that is commonly a mistake but can be perfectly legitimate. These are phrased as questions to ask, never as accusations.

Know your rights is background, not a problem with your bill. Itemized bills on request, the No Surprises Act, financial assistance policies, and what to do when a bill arrives long after the care did.

Then it helps you act. Every finding comes with the exact wording to use, what the billing department is likely to say back, and how to respond. The app writes the full review letter for you, listing each charge you flagged. If your bill is only a summary, it writes the itemized bill request instead, because most errors are invisible until you have the detailed version.

Everything stays on the device. No account, no server, no upload. The app works identically in airplane mode, which is the easiest way to prove the claim rather than just make it.

## How I built it

SwiftUI for the interface, targeting iOS 17. Vision for text recognition, with a custom row-grouping pass that reassembles recognised fragments into bill lines by vertical position, because Vision returns words, not rows. VisionKit for document capture.

The analysis is a rules engine, not a model. Forty-six rules, written as plain Swift, running against a parsed representation of the bill. That choice was made for a specific reason: a rules engine can explain exactly why it flagged something, and a user about to call a hospital needs to be able to say what is wrong, not that an app told them so.

RevenueCat handles the subscription. Lime Shield Pro is 2.99 a month for unlimited scans and unlimited letters. The free tier includes the complete analysis, not a crippled version of it, because an app whose whole point is helping people who cannot absorb a surprise bill should not put the answer behind a paywall.

## Challenges I ran into

The hardest problem was not building the rules. It was discovering they were wrong.

Once the app worked, I stopped adding features and started trying to break it. I generated a set of adversarial bills designed to defeat the parser, and I found real hospital statements published online to test against. Then I ran them.

The arithmetic rule, the one rule that states its findings as errors rather than questions, was wrong more often than it was right. Across the stress set it produced one correct finding and four false ones. It also accused a genuine, entirely correct hospital statement of not adding up.

Four separate causes. Payment and adjustment lines were being counted as charges. Subtotal rows were being counted as line items. Amounts were bleeding across columns on multi-column layouts. And the amount regex silently truncated any figure without a comma, so 1284.00 was read as 284.00.

I rewrote the parser. Summary rows are now identified and excluded before anything else. Non-charge keywords are matched with word boundaries and only against the text before the first amount, so a Coinsurance column heading cannot disqualify the charge next to it. Rows with several money columns mark the bill as ambiguous, and every total-dependent rule goes quiet when totals are not reliable.

Then I did the thing that actually mattered: I ported the classification logic to Python and built a fixture set, so I could verify the fix instead of believing in it. That harness caught two regressions I introduced while fixing the original bug. One dropped a legitimate 54 dollar charge. The other dropped a line reading INTEREST ON UNPAID BALANCE, because unpaid contains paid.

The principle I ended up with: a rule that stays silent beats a rule that accuses an honest provider. Someone who walks into a billing office quoting a false error from my app is worse off than someone who never opened it.

A second hole turned up from the same testing. The app told users to request an itemized bill, then refused to analyze the itemization when it arrived, because the document detector lumped provider itemizations in with insurer Explanations of Benefits. It was telling people to do the right thing and then punishing them for it. Fixed by separating the two document types: EOBs still stop, because their numbers are not what you owe, and itemizations are analyzed like any other bill.

## Accomplishments I am proud of

That the app is willing to say nothing. It would have been easy to ship something that flags plenty on every bill and feels impressive. What it does instead is stay quiet when it cannot be sure, and the work that made it quiet was most of the work.

That the privacy claim is literal rather than marketing. There is no server to trust, no policy to read, no setting to switch off. Airplane mode changes nothing.

That the language was designed as carefully as the code. Three tiers, and only one of them is allowed to use the word error.

## What I learned

That testing a thing you built against material you did not choose is uncomfortable and completely necessary. Every serious flaw came from the real bills and the adversarial ones, not from the examples I had been developing against.

That verifying a fix is a separate job from making it. I would have shipped both of my own regressions if I had not built the harness first.

That in a domain where being wrong costs a user something real, restraint is a feature.

## What is next

Reference prices with citations, so the price comparison rule can show its source instead of a range.

The sixteen rules that have never fired in testing. Each one needs a bill that triggers it, or it is decoration.

A letter allowance separate from the scan allowance, which is a rough edge in the free tier.

And a proper answer to the question underneath all of this: how many of these findings, when people actually raise them, turn into money back. That takes real users, which is what comes after shipping.

---

## Built with

Swift, SwiftUI, Vision, VisionKit, RevenueCat, Xcode, Python (for the verification harness)

## Links

App Store: https://apps.apple.com/us/app/lime-shield/id6811397021
Privacy policy: https://dishurise-create.github.io/limeshield/privacy.html
Support: https://dishurise-create.github.io/limeshield/support.html
