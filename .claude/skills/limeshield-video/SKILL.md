---
name: limeshield-video
description: Make a Lime Shield promo video ("What If" 2D animated short, 30-40 s, 9:16) end to end. Use when the user asks for a new Lime Shield video, TikTok, Reel, Short, or "make the next video". Runs in stages with user checkpoints: pitch ideas → user picks → write script → WAIT for the user's ElevenLabs voiceover → build the video in the aiTrends 2D Studio → captions for every platform → cover photo.
---

# Lime Shield video pipeline

Five stages. Stop at each checkpoint (⏸) and wait for the user. Never skip ahead.

Lime Shield facts you may use (all true): free iPhone app, reads a photo of a
medical bill, about 50 checks, runs entirely on the phone (the bill never
leaves it), Bill X-ray reveal, Shield Buddy, writes a polite letter asking for
the itemized bill or a review, built by an 11th grader, free to try (1-week
trial on Pro). App Store: https://apps.apple.com/us/app/lime-shield/id6811397021

Brand rule (from CLAUDE.md): never say or show that a hospital is wrong,
cheating or made an "error". Flagged charges are "worth asking about".
Highlights are orange, never red. Never invent statistics or studies.

---

## Stage 1: Pitch ideas ⏸

Before pitching, list the earlier videos in `~/Documents/LimeSheild app/aitrends-2d-studio/projects/`
and in `social/posts/tiktok/` so nothing repeats.

Pitch **5 ideas**. Each one gets:
- **Title**: "What If ...?" format, 6-8 words, Title Case, about the viewer
  (You/Your), one change pushed to an extreme, readable in 2 seconds.
- **Hook (first line, under 2 s)**: the exact opening words (see Hook rules).
- **The bill moment**: which real app check the video dramatises. Pick from
  the rules engine (`LimeShield/RulesEngine*.swift`), e.g. duplicate lines on
  the same day (`blood_draw_repeat`, `repeat_across_dates`), `comfort_items`
  ("tissues", "misc supplies"), `same_code_two_prices`, `quantity_math`,
  `math_statement`, `not_itemized`, `surprise_billing` (No Surprises Act),
  `credit_balance` (they owe YOU money), `already_paid`, `financial_assistance`,
  `self_pay_no_discount`, `missed_appointment_fee`, `out_of_network`,
  insurer EOB mistaken for a bill.
- **Why people stop scrolling**: one line.

Mark your favourite with ⭐. Then ask the user to pick one, or mix and match.

## Stage 2: Script ⏸

Write the script in the channel voice. Output exactly:
```
TOPIC: <title>
SCRIPT: <one paragraph of spoken text>
```
- **80-95 words** (30-40 s). Check by timing it:
  `say -r 175 -f script.txt -o /tmp/x.aiff && afinfo /tmp/x.aiff | grep duration`
  It must come out at 30-40 s. Trim if longer.
- Second person, present tense. Very short sentences (4-5 words on average).
  "..." before every payoff. Numbers written out in words. A "Most people...
  You?" contrast. One question for the comments at the end.
- Structure: hook (0-2 s) → the bill and the stakes (2-8 s) → the X-ray/scan
  moment (8-20 s) → the calm lesson ("you just ask for the itemized bill") →
  title restated as the turn ("So what if you had...? Turns out... you can.") →
  Lime Shield reveal with 2-3 true facts → comment question.
- Save it to `social/posts/tiktok/<slug>/script.md`.

### Hook rules (the user wants stronger hooks than video 1)
Video 1 opened by reading the title ("What if you had X-ray vision for
bills?"), which is OK but slow. Do better:
- **The first words are the hook, not the title.** The title appears on screen
  as text; the narrator says it later as the turn.
- Open **mid-moment with a concrete, specific image or number**: "This bill has
  the same test... twice." / "Forty dollars. Then forty dollars again." /
  "You're about to pay for tissues. Three hundred forty dollars of them."
- Or a **pattern interrupt aimed at the viewer**: "Don't pay that bill yet."
  / "Your hospital bill has a secret back page." (Only if it's true for the video.)
- Or an **open loop** that the video pays off: "One line on this bill... is
  worth a phone call."
- Under 2 seconds, under 8 words, no setup, no "Hey guys", no title first.
- Show the payoff visual in the first frame (the glowing line, the number), so
  a muted scroller gets it too.
- Must still be honest: no fake statistics, no "hospitals are scamming you".

Then tell the user exactly what to do next:
1. Paste **only the SCRIPT text** (not the TOPIC line) into ElevenLabs. Voice
   used so far: "Mike - 2D & 3D POV Storytime".
2. Download the MP3 into `~/Documents/LimeSheild app/`.
3. Say "voiceover's ready".

**⏸ WAIT here until the user says the voiceover is ready.** Do not start the video.

## Stage 3: Build the video

Use the installed aiTrends 2D Studio skills (`aitrends-2d-studio:make-2d-video`,
which covers new-video, render-video and video-sound) and follow them, with these
Lime Shield specifics:

- Studio: `~/Documents/LimeSheild app/aitrends-2d-studio/`. **Always first**
  `export PATH="$HOME/.local/aitrends-tools/bin:$PATH"` (Node and ffmpeg live there;
  without it doctor reports MISSING). `python3`, not `python`.
- Settings: 9:16, 1080p, captions on, generated music + SFX, style `dusk`.
  Don't ask the user about settings or style; just go.
- New project: `python3 tools/new_project.py --name <slug> --voice "<mp3>" --script <script.txt> --aspect 9:16 --resolution 1080p --title "<title>" --captions`,
  then `tools/transcribe.py ... --model small`, then `tools/beats.py --force`.
  If the voiceover also says the title, add it to script.txt where it is
  spoken and re-run transcribe. A match of about 87% is fine when the only
  differences are digits ("50" vs "fifty"). Check `timeline/transcript.txt`.
- **Reuse video 1** (`projects/limeshield-xray`) instead of starting from
  nothing: copy `scenes/cast.js` (YOU = lime-green hoodie `#3fb950`) and the
  sets in `scenes/sets/` (`kitchen.js`: night kitchen, table, mug,
  `paperBill`, `phone`, `arm`, `shield` emblem, `LIME`/`ORANGE`; `xray.js`:
  blueprint bill rows + gold scan `beam`; `desk.js`: bedroom desk + laptop).
  Edit `ROWS` in kitchen.js for the new bill. Write new shots for the new story.
- Signature beats to keep in every video: flash into X-ray mode with the gold
  beam sweep; flagged lines glow orange; a calm "just ask" moment; the glowing
  lime shield + "LIME SHIELD" reveal; "FREE TO TRY"; an end screen with the
  comment question and a Lime Shield pill.
- Framing lessons from video 1: in 9:16, standing figures need `s` ≈ 2.3-2.5
  (1.5 looks tiny); table top = `GY - 92*s`; keep text out of the bottom 25%
  (captions sit at 79% of the height); keep readouts clear of arms and props;
  give big numbers a dark panel behind them so they don't collide with rows.
- Shot plan: about 18-20 shots for 38 s, median about 1.8 s (fast for TikTok).
  Captions off on title cards and the end screen.
- Look before rendering: `node render.mjs --project projects/<slug> --sheet --scale 0.5`,
  read `build/sheets/sheet_01.png`, fix, then check with `--stills`.
- Final: `node render.mjs --project projects/<slug> --format jpeg` (about 1 min),
  then `python3 audio/mix.py --project projects/<slug>`. Check with ffprobe
  (1080x1920, audio present, duration matches) and a contact sheet.
- Copy to `~/Documents/LimeSheild app/LimeShield-<slug>.mp4` and send it with
  SendUserFile.

## Stage 4: Captions

Give one ready-to-paste caption per platform, each in its own code block:
- **TikTok**: hook line + 2-3 short lines + "link in bio" + comment question + 4-5 hashtags.
- **Instagram Reels**: a little longer, "link in bio", about 8 hashtags; post as a Reel.
- **YouTube Shorts**: title under 100 characters with #shorts, plus a description with the App Store link.
- **Facebook**: a longer, warmer version, link in the post (upload the video natively).
- **X**: under 280 characters including the link.
Every caption: "built by an 11th grader", "free to try", never accusatory.
Save them to `social/posts/tiktok/<slug>/captions.md`.

## Stage 5: Cover photo

Copy `projects/limeshield-cover` (a one-shot project: config duration 2,
captions off, single shot id `cover`) to a new project and rewrite
`scenes/shots/04_cover.js` for this video: title text in the top 30%, the key
bill moment in the middle, the buddy face and the Lime Shield pill at the
bottom. Keep the important parts between 12% and 88% of the height
(Instagram's 3:4 grid crop). Render with `--stills 1.0 --scale 1`, look at it,
fix overlaps, save as `~/Documents/LimeSheild app/LimeShield-<slug>-cover.png`,
and send it.

Finish with a short list: where the MP4 and cover are, and the order to post
(all platforms the same evening; pin a comment answering your own question).
