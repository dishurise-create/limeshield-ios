# Lime Shield, build in public posts

Six posts for X, spaced across the final ten days. Every one of them gets
#BuildInPublic and #Shipaton. Post the second one early, it is the strongest.

Each post below lists what to attach. A post without media gets a fraction of
the reach of one with, so do not skip the attachments.

---

## Post 1, day one. What it is.

Attach: a short clip of airplane mode being switched on, then a bill being
scanned, then findings appearing.

```
I'm in 10th grade and I built an app that checks medical bills for billing errors.

It reads the bill on your phone. No server, no account, no upload. Your bill never leaves the device.

Here it is working in airplane mode.

#BuildInPublic #Shipaton
```

---

## Post 2, day two or three. The day it was wrong.

This is the post. Attach a screenshot of the false "Likely error" verdict against
the real hospital statement, ideally next to the bill showing the totals were
actually fine.

```
My app has one rule that says "Likely error" instead of "worth checking".

I tested it on real hospital bills and adversarial ones I built to break it.

It was right once and wrong four times. It also accused a real, completely correct statement of not adding up.

#BuildInPublic
```

Reply to your own post with the causes, as a second tweet:

```
Four bugs, all in the parser rather than the rule:

- payments and adjustments counted as charges
- subtotal rows counted as line items
- amounts bleeding across columns
- the regex silently cut "1284.00" down to "284.00"
```

---

## Post 3, day four. The fix, and the part I did not expect.

Attach: a screenshot of the Python fixture output, all passing.

```
Fixing it wasn't the hard part. Proving the fix was.

So I ported the logic to Python and built a set of test bills with known answers.

That harness caught two bugs I introduced while fixing the first one. One dropped a $54 charge. The other dropped a line reading INTEREST ON UNPAID BALANCE, because "unpaid" contains "paid".

#BuildInPublic
```

---

## Post 4, day five. The design rule that came out of it.

No attachment needed, or a screenshot of the three severity tiers in the app.

```
The rule I ended up with:

An app that stays silent beats an app that accuses an honest provider.

Someone who walks into a billing office quoting a false error from my app is worse off than someone who never opened it.

So now every total-based check goes quiet when the totals aren't reliable.

#BuildInPublic
```

---

## Post 5, when Apple responds. The rejection.

Attach: a screenshot of the 2.1 message. Post this whether the news is good or
bad, and post it the day it happens.

```
First app, first submission, first rejection.

Guideline 2.1, information needed. New developer accounts get asked for a video and a writeup before a human finishes the review.

Also found a real problem while fixing it: my paywall showed the price but not the subscription length. Apple was right.

#BuildInPublic
```

---

## Post 6, on approval. The link.

Attach: the App Store listing screenshot, or the app icon on a home screen.

```
Lime Shield is live.

Scan a medical bill, get told what's worth questioning and exactly what to say when you call. 46 checks. Runs entirely on your phone.

Built for #Shipaton. Ten days ago it was confidently accusing innocent hospitals of arithmetic errors.

[App Store link]

#BuildInPublic
```

---

## Notes on doing this well

Post the failure posts. Almost nobody does, which is exactly why they land, and
the #BuildInPublic award is judged on transparency rather than polish.

Do not batch all six on the last day. The timestamps are visible and judges can
tell the difference between a build log and a press release.

Reply to anyone who comments. A thread with real conversation under it reads
completely differently from one with none.

Keep the tone flat. The work is interesting on its own and does not need
exclamation marks holding it up.
