---
name: limeshield-video
description: Make a Lime Shield promo video ("What If" 2D animated short, 30-40 s, 9:16) end to end. Use when the user asks for a new Lime Shield video, Reel, Short, or "make the next video". Posted to YouTube Shorts, Instagram Reels, Facebook and X (not TikTok). Runs in stages with user checkpoints: pitch ideas → user picks → write script → WAIT for the user's ElevenLabs voiceover → build the video in the aiTrends 2D Studio → captions for every platform → cover photo.
---

# Lime Shield video pipeline

Five stages. Stop at each checkpoint (⏸) and wait for the user. Never skip ahead.

Platforms: **YouTube Shorts, Instagram Reels, Facebook, X.** The user does
NOT post to TikTok; don't write TikTok captions or TikTok advice. (The
`social/posts/tiktok/` folder name is historical; keep using it.)

Video log: `social/posts/tiktok/video-log.md` (create if missing), one row per
video: slug, date, type (app / tip), set used, story structure, hook. Read it
in Stage 1, add a row at the end of Stage 5.

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
and in `social/posts/tiktok/` (plus the video log) so nothing repeats. Then search
the web (YouTube, Instagram) for each candidate topic: if a big video (≈1M+
views) already tells that exact story, drop it or find a fresh angle, and say
so in the pitch.

**App videos vs tip videos.** Accounts that post mostly ads get less reach;
aim for roughly 4 tip videos to every 1 app video over time (check the log).
- **App video**: full formula, Lime Shield reveal (≈5 s), X-ray beat.
- **Tip video**: pure bill tip that helps even people who never download
  anything; Lime Shield appears only as a 2-second pill/watermark at the end
  (no reveal, no "free to try" line in the voiceover; the caption carries the
  app mention).
Label every pitch APP or TIP, and say which one the log says is due.

**Vary each video.** YouTube demotes near-identical template videos. Each new
video uses a different main set or a new one (kitchen, desk, a pharmacy
counter, a mailbox, a car, a waiting room...) and a different story shape
(countdown, before/after, myth vs fact, one bill line close-up, a race...)
from the last two in the log.

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
- **Type**: APP or TIP.
- **Why people stop scrolling**: one line.

Mark your favourite with ⭐. Then ask the user to pick one, or mix and match.

## Stage 2: Script ⏸

Write the script in the channel voice. Output exactly:
```
TOPIC: <title>
SCRIPT: <one paragraph of spoken text>
```
- **105-120 words** (30-38 s). Viral shorts run about 3.5-4 words a second
  with almost no dead air; videos 1-2 ran 2.5 and felt slow. Check by timing it:
  `say -r 210 -f script.txt -o /tmp/x.aiff && afinfo /tmp/x.aiff | grep duration`
  It must come out at 30-38 s. Trim if longer.
- Second person, present tense, plain spoken English, contractions. Numbers
  written out in words. **At most 2-3 "..." in the whole script**, only before
  the biggest payoffs; everything else flows straight on.
- **Write the hook and the last line first**, then fill in the middle. The
  last line must **loop into the hook**: read the last line, then the first,
  and it should sound like one sentence (e.g. last "...so next time a bill
  says" → first "negative eighty dollars, don't throw it out."). Viewers who
  don't notice the restart rewatch, and rewatches are a big signal.
- Join beats with **"but" and "so"**, never "and then". Each beat should cause
  or complicate the next.
- **Formula** (from studying viral animated shorts):
  1. **Hook** (0-2 s): a strange-but-true bill moment stated as fact. No setup.
     Say a **search phrase** ("hospital bill", "medical bill", "itemized bill")
     in the hook or within the first 5 s; YouTube and Instagram search read the
     speech, on-screen text and caption.
  1b. **Foreshadow** (2-4 s, one short line): what's coming, the conflict, and
     what the viewer gets by the end ("One of these lines is worth a phone
     call. Let's find it.").
  2. **Setting + stakes** (4-8 s): the bill, the number, concrete details.
  3. **Escalation** (8-18 s): 2-3 beats, each a little bigger (the X-ray/scan
     moment, flagged lines glowing).
  4. **"You see,"**: the pivot into the explanation, with an **everyday
     comparison** ("You see, a hospital bill is like a restaurant receipt. You'd
     never pay one that just says 'Food: two thousand dollars.'").
  5. **One "Luckily... / Unluckily..." deadpan line built on a true fact**
     ("Luckily, it was only one blood test. Unluckily, you paid for it twice.").
     Must be honest and match a real app check; never imply fraud.
  6. **The calm lesson**: you just ask (itemized bill, review).
  7. **APP videos only: Lime Shield in about 5 s max**: name + 2 true facts +
     "free to try". (TIP videos skip this; the end pill does the work.)
  8. **End on the strongest feeling**: the biggest twist or the funniest line,
     which is also the loop line back into the hook. No slow fade, no "thanks
     for watching". The comment question goes in the caption/pinned comment.
- The title is shown on screen; the narrator doesn't have to say it.
- Facts first: write the true facts the script relies on at the top of
  `script.md` (which rule fires, what the law says) before writing the lines.
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
- **The hook must work on mute.** Frame 1 has all three at once: the picture
  (the glowing line, the number), a short on-screen hook text (≤6 words, top
  third, big, dark panel behind it), and the spoken hook. Frame 1 should also
  work as the thumbnail.
- Must still be honest: no fake statistics, no "hospitals are scamming you".

Then tell the user exactly what to do next:
1. Paste **only the SCRIPT text** (not the TOPIC line) into ElevenLabs. Voice
   used so far: "Mike - 2D & 3D POV Storytime". Nudge the **Speed** slider up a
   little (about 1.05-1.1) so it lands near 3.5 words a second.
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
  lime shield + "LIME SHIELD" reveal; "FREE TO TRY" (APP videos). TIP videos
  keep the X-ray look but end with only a small Lime Shield pill over the
  final shot (no end card, so the loop still works).
- Framing lessons from video 1: in 9:16, standing figures need `s` ≈ 2.3-2.5
  (1.5 looks tiny); table top = `GY - 92*s`; keep readouts clear of arms and
  props; give big numbers a dark panel behind them so they don't collide with rows.
- **Safe zones (Shorts/Reels buttons and caption overlay)**: nothing important
  in the bottom 420 px, the right 140 px (like/comment/share column) or the
  top 200 px of the 1080x1920 frame. Keep all text and key props inside the
  central x 80-940, y 200-1500 box. Captions sit at y ≈ 1380 (72%).
- **config.json settings** (set right after new_project):
  `"fps": 30`, `"captionStyle": {"max": 1, "y": 1380}` (one word at a time,
  gold pop on the current word, above the app overlays),
  `"music": {"enabled": true, "gainDb": -10}` (music ~10 dB under the voice,
  not 17), `"fadeIn": 0` (hook visible at frame 0), `"fadeOut": 0` (so the
  loop back to frame 1 is seamless).
- **Loop the picture too**: the last shot ends on (or glides into) the same
  framing as shot 1, so the restart feels continuous. The last words land in
  the last 0.3 s; no dead tail.
- **Shot plan**: about 14-18 shots for 35 s. Almost no hard cuts: join shots
  with the studio's transitions in shots.json (`"in": {"type": "flash"}` after
  the hook and on big reveals, `"fade"`/`"dipWhite"` 0.25-0.3 s for place
  changes, `"zoom"` into the X-ray, `"whip"` at most once). A hard cut only for
  a deliberate jolt. Captions off on title cards and the end screen.
- **Camera always moving**: every shot slowly pushes in (about 3-8% scale over
  the shot, faster on punch words). No static holds. Moves glide over about
  0.8-1 s with ease in-out (`ease.inOut`), never a 3-frame snap. Small 3-5°
  tilts for drama. Every visual reaction lands 0-3 frames before its word
  (`wordTime()`).
- **Lighting follows the story**: setup warm and bright (amber key), switch to
  deep night blue at the "You see," explanation, back to warm/lime for the Lime
  Shield reveal. No pure black anywhere (lift the darks); shadows purple-blue,
  never brown. Saturated colours.
- **Sound design**: short midrange "zip" whooshes on transitions (they read on
  phone speakers; skip long bassy sweeps), one riser only before the big
  reveal, a hit on the flagged-line glow. Use SFX as punctuation, not on every
  cut.
- Look before rendering: `node render.mjs --project projects/<slug> --sheet --scale 0.5`,
  read `build/sheets/sheet_01.png`, fix, then check with `--stills`.
- **Independent check before the final render**: give a fresh agent the
  contact sheet + 3-4 stills and have it score out of 10: hook clarity in frame
  1 (works on mute?), readability (text clear of captions/props and inside the
  safe zone), loop (does the last frame flow into the first?), camera motion, colour/lighting,
  character framing, brand rules (orange not red, nothing accusatory). It
  returns a numbered fix list with timestamps. Fix, re-check stills, then render.
  Measure, don't opine: ask for numbers and specific frames, not impressions.
- Final: `node render.mjs --project projects/<slug> --format jpeg` (about 1.5 min at 30 fps),
  then `python3 audio/mix.py --project projects/<slug>`. Check with ffprobe
  (1080x1920, audio present, duration matches) and a contact sheet.
- Copy to `~/Documents/LimeSheild app/LimeShield-<slug>.mp4` and send it with
  SendUserFile.

## Stage 4: Captions

Give one ready-to-paste caption per platform, each in its own code block:
- **YouTube Shorts**: title under 100 characters with the search phrase near
  the front and #shorts, plus a description with the App Store link (Shorts
  description links aren't clickable in the player, so also pin a comment).
  Remind the user to set **"Related video"** in YouTube Studio (Details →
  Related video, desktop) to the previous Lime Shield Short, so the Shorts
  link into each other.
- **Instagram Reels**: search phrase in the first line, "link in bio", about
  8 hashtags; post as a Reel.
- **Facebook**: a longer, warmer version, link in the post (upload the video natively).
- **X**: under 280 characters including the link.
Every caption: the same search phrase that's spoken and on screen; a **send
line** ("Send this to someone who just got a hospital bill." Instagram counts
shares sent per view as a top signal); "built by an 11th grader"; never
accusatory. APP videos add "free to try". TIP videos mention Lime Shield
lightly in the last line only.
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

Add the video's row to `social/posts/tiktok/video-log.md` (slug, date,
APP/TIP, set, story shape, hook).

Finish with a short list: where the MP4 and cover are, and the order to post
(all platforms the same evening; pin a comment answering your own question;
set the YouTube Related video link).
