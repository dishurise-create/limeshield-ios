# Captions

Short. The image does the arguing. Every post gets #BuildInPublic and #Shipaton.

Order: r3, then the 4/5 one, then r4, r1, r2, r5, then launch.

---

## r3-private.png

```
Medical bills are impossible to read and I don't think that's an accident.

I'm in 10th grade. I got annoyed enough that I built an app that reads them for you. Point your phone at a bill and it tells you what looks off.

Every other app like this makes you upload the bill first. Mine has no server to upload it to.

#BuildInPublic #Shipaton
```

---

## 03-wrong.png (keep the designed card for this one)

Post this second. It's the one that makes people take you seriously.

```
Reality check on my own app.

I built it to catch medical billing errors. Then I tested it on real hospital bills instead of my own fake ones.

It was wrong 4 times out of 5. It told me a real bill didn't add up when it added up fine.

That's not a small bug. That's someone calling a hospital and getting embarrassed because my app lied to them.

So I deleted the parser and wrote it again.

#BuildInPublic
```

Reply to yourself:

```
The four bugs, none of them in the rule itself:

payments counted as charges
subtotal rows counted as line items
numbers bleeding in from the next column
my regex quietly turning 1284.00 into 284.00

Then I rewrote the logic in Python with test bills where I already knew the answer, so I could prove the fix instead of hoping.

It caught two more bugs I'd just made.
```

---

## r4-supplies.png

Say it's a test bill. It costs you nothing and it kills the "that's staged"
reply before anyone types it.

```
One of the test bills I use, run through the app.

Sterile gloves, $192. Tylenol, $144. A fee for being treated in the evening.

None of these are illegal. All of them are negotiable. Almost nobody asks, because almost nobody can tell they're there.

#BuildInPublic
```

---

## r1-nothing.png

```
My app is allowed to find nothing.

That sounds obvious. It isn't. Every incentive pushes you to flag something on every bill, because a flag feels like the app is working.

But a false alarm sends someone into a fight they didn't need to have. So when the numbers aren't reliable, it says so and shuts up.

#BuildInPublic
```

---

## r2-finding.png

```
Flagging the charge is the easy half.

The hard half is that most people have never argued with a hospital billing department and have no idea what to say.

So every finding comes with the exact words, what they'll probably say back, and how to answer that.

#BuildInPublic #Shipaton
```

---

## r5-letter.png

```
And then it writes the letter.

Every charge you flagged, listed out, ready to send. You fill in your name.

Getting a bill reviewed shouldn't require knowing how to write a formal letter at 11pm.

#BuildInPublic
```

---

## Launch day

Use the App Store listing or the icon on your home screen.

```
Lime Shield is live.

Point it at a medical bill, it tells you what's worth asking about and writes the letter for you. Nothing leaves your phone.

Two weeks ago this thing was confidently telling me innocent hospitals couldn't do math. That's what the two weeks were for.

[App Store link]

#BuildInPublic #Shipaton
```

---

## Two things to be careful about

Stay angry at the billing system, not at doctors or nurses. Billing is a
different building from the people who treated you, and blurring that gets you
argued with by the exact people you want agreeing with you.

Don't quote a percentage of bills that contain errors. The number everyone
repeats is badly sourced and someone will call you on it. "Bills are unreadable
and nobody checks them" is true and is the actual problem anyway.
