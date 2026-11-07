---
name: limeshield-video
description: Make a Lime Shield promo video (2D animated short in the bright Rick's-Clips-like cartoon style, 30-40 s, 9:16, emphasis-moment hook) end to end. Use when the user asks for a new Lime Shield video, Reel, Short, or "make the next video". Posted to YouTube Shorts, Instagram Reels, TikTok, Facebook and X. Runs in stages with user checkpoints: pitch ideas → user picks → write script → WAIT for the user's ElevenLabs voiceover → build the video in the aiTrends 2D Studio → captions for every platform → cover photo.
---

# Lime Shield video pipeline

Five stages. Stop at each checkpoint (⏸) and wait for the user. Never skip ahead.

Platforms: **YouTube Shorts, Instagram Reels, TikTok, Facebook, X.** The user
started TikTok on 2026-11-05 (stats reach the Socials dashboard through
Metricool). Write a TikTok caption for every video. Files live in
`social/posts/tiktok/`.

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

**Start from the idea bank**: `social/posts/tiktok/idea-bank.md` holds researched
scenarios where Lime Shield is the clear solution (each mapped to a real check
and app feature). Pitch from it first (mark used ones as done), and add new
ideas to it.

Pitch **5 ideas**. Each one gets:
- **Title**: since video 7, Rick's-Clips-style **"Why ..."** curiosity title
  about a character ("Why He Was Buried in Gauze Pads", "Why Grandma Paid a Bill
  That Wasn't a Bill"), 5-8 words, Title Case, readable in 2 seconds. (Videos
  1-6 used "What If ...?".)
- **Hook (first line, under 2 s)**: the exact opening words AND the frame-1
  emphasis moment, the loudest picture in the story (see Hook rules).
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
- **95-108 words** (target 30-35 s). Calibrated on video 3: the ElevenLabs
  "Mike" voice at Speed 1.10 read 121 words in 40 s (3.0 words/s), too slow and
  too long. Viral shorts run 3.5-4 words/s. So: at most 108 words, and the user
  sets Speed to **1.2** (the maximum). Check with
  `say -r 210 -f script.txt -o /tmp/x.aiff && afinfo /tmp/x.aiff | grep duration`:
  it must come out at 26-31 s (ElevenLabs runs ~15% slower than `say -r 210`).
- **Third person** ("He stayed one night..."), told like a little true-ish
  legend, the Rick's Clips way (since video 7; videos 1-6 were "you"). Present
  or past tense, plain spoken English, contractions. Numbers
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
  1b. **Foreshadow** (2-4 s, one short line) that **promises a payoff**: it must
     tell the viewer what they'll get by the end ("Here's the one question
     that fixes it." / "One of these lines is worth a phone call. Let's find
     it."). A line that only states the stakes ("it's too late") does NOT count
     (video 3 made this mistake).
  2. **Setting + stakes** (4-8 s): the bill, the number, concrete details.
  3. **Escalation** (8-18 s): 2-3 beats, each a little bigger (the X-ray/scan
     moment, flagged lines glowing).
  4. **"You see,"**: the pivot into the explanation, with an **everyday
     comparison** ("You see, a hospital bill is like a restaurant receipt. You'd
     never pay one that just says 'Food: two thousand dollars.'").
  5. **The twist line**: one short, honest line built on a true fact that ties
     the comparison back to the bill ("Nobody checks the middle, so the twin
     hides on page five."). Must match a real app check; never imply fraud.
     **Never use the "Luckily... / Unluckily..." pattern** (the user asked for
     it to be dropped, 2026-11-05).
  6. **The calm lesson**: you just ask (itemized bill, review).
  7. **APP videos only: Lime Shield in about 5 s max**: name + 2 true facts +
     "free to try". (TIP videos skip this; the end pill does the work.)
  8. **End on the strongest feeling**: the biggest twist or the funniest line,
     which is also the loop line back into the hook. Test it twice: (a) read
     last line → first line, it must sound like one sentence; (b) read the last
     line alone, it must land as a punchline or twist even without the loop.
     Video 3's "So next time you book, and they ask..." passed (a) but failed
     (b). No slow fade, no "thanks for watching". The comment question goes in
     the caption/pinned comment.
- The title is **shown on screen inside the video** (not only on the cover):
  a ~1 s title overlay on a transition beat (e.g. after the foreshadow, or
  over the "You see," turn), top third, dark panel. The narrator doesn't say it.
- Facts first: write the true facts the script relies on at the top of
  `script.md` (which rule fires, what the law says) before writing the lines.
- Save it to `social/posts/tiktok/<slug>/script.md`.

### Hook rules (the user wants stronger hooks than video 1)
**The hook is a moment of emphasis (user rule, 2026-11-06).** Too many viewers
swiped away in the first second on every platform, because frame 1 was calm.
Now frame 1 is the **loudest moment of the whole story** (the climax picture,
not the setup): the gauze avalanche burying the bed, the stamp slamming down,
the number hitting the screen. On frame 1, all at once:
- the character frozen mid-reaction (shock face, comic impact lines);
- a camera impact: start slightly pushed in with a short shake that decays in
  about 0.4 s, then keep pushing;
- a hit + stinger SFX at 0.0 s;
- the spoken hook stated as plain fact, under 8 words;
- the on-screen hook text (≤6 words, top third, dark panel).
The story then rewinds ("He stayed one night.") to explain how it got there.
No calm establishing shot first, ever.

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

**⏸ Pre-voiceover checklist.** Show this table to the user under the script,
every row filled in honestly (✅ / ❌ + the exact line). Fix any ❌ before
asking for the voiceover:
| Check | Line / number |
|---|---|
| Hook ≤ 8 words, strange-but-true, search phrase in first 5 s | |
| Frame 1 = the loudest moment of the story (emphasis hook) | |
| Foreshadow promises a payoff | |
| "but/so" links, no "and then" | |
| "You see," + everyday comparison | |
| Honest twist line (no "Luckily / Unluckily") | |
| Calm lesson (just ask) | |
| APP: Lime Shield ≤ 5 s with a clear, true solution / TIP: no app line | |
| Last line: loops into hook AND lands alone as a punchline | |
| 95-108 words, `say -r 210` 26-31 s | |
| Where the title appears on screen | |
| Facts written at top of script.md with sources | |

Then tell the user exactly what to do next:
1. Paste **only the SCRIPT text** (not the TOPIC line) into ElevenLabs. Voice
   used so far: "Mike - 2D & 3D POV Storytime". Set the **Speed** slider to
   **1.2** (the maximum).
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
- Settings: 9:16, 1080p, captions on, generated music + SFX, style
  **`daylight`** (added to `engine/styles.js` for video 7). Don't ask the user
  about settings or style; just go.
- **Visual style (since video 7, user's choice, modelled on the YouTube
  channel Rick's Clips, @ricksclips55)**:
  - **Characters**: `scenes/lib/toon.js` from `projects/limeshield-gauze`
    (`toon()` / `toonHead()`): big round WHITE head with a thick black outline,
    small bean body with a patterned top (plaid / stripes / diamond), black
    stick arms and legs, faces `deadpan` (half-lidded, thick brows) / `shock` /
    `squint` / `calm` / `sleep`, optional `hair` or `cap`. NOT the old black
    stick-figure rig. Head radius ≈ 110-125 for standing wide shots.
  - **Sets**: bright saturated daylight, deep perspective, low camera. Use 3D
    (Three.js, `sets/room3d.js` pattern) for rooms, with the 2D character
    drawn on top via `overlay` and positioned with `project()`; 2D sets
    (`sets/porch.js` pattern) with parallax `layer()`s for outdoors.
    Close-ups on bright sunburst backgrounds (`sets/paper.js`: `bigBill`,
    `phone`, `sunburst`, `pizzaBox`, `syringe`).
  - **Keep the character on screen** in most shots (the reviewer's main
    note on video 7: half the shots were object-only close-ups). Put a small
    reaction head or hand in close-ups.
  - Rick's backgrounds have painted textures (wood grain, gravel); ours are
    smoother. Add canvas textures to 3D materials when there's time.
  - Night/dark scenes only for a deliberate flashback; otherwise stay bright.
- New project: `python3 tools/new_project.py --name <slug> --voice "<mp3>" --script <script.txt> --aspect 9:16 --resolution 1080p --title "<title>" --captions`,
  then `tools/transcribe.py ... --model small`, then `tools/beats.py --force`.
  If the voiceover also says the title, add it to script.txt where it is
  spoken and re-run transcribe. A match of about 87% is fine when the only
  differences are digits ("50" vs "fifty"). Check `timeline/transcript.txt`.
- **Cut the title read-out**: ElevenLabs reads the TOPIC line first even when
  only the script is pasted (happened in all 3 videos). Find the first silence
  with `ffmpeg -i input/voiceover.mp3 -af silencedetect=n=-40dB:d=0.2 -f null -`,
  check those seconds with Whisper, keep the original as
  `input/voiceover_with_title.mp3`, and trim with
  `ffmpeg -ss <cut> -i input/voiceover_with_title.mp3 -c:a libmp3lame -b:a 192k input/voiceover.mp3`,
  then re-run transcribe. The hook must start at ~0.0 s.
- **Pace check**: words ÷ duration after trimming. If under 3.3 words/s or
  longer than 36 s, speed the voice up (pitch stays the same) before building:
  `ffmpeg -i input/voiceover.mp3 -filter:a atempo=1.08 input/voiceover_fast.mp3`
  (max 1.12), swap it in, re-run transcribe and beats.
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
- **Safe zones (Shorts/Reels/TikTok buttons and caption overlay)**: nothing important
  in the bottom 420 px, the right 140 px (like/comment/share column) or the
  top 200 px of the 1080x1920 frame. Keep all text and key props inside the
  central x 80-940, y 200-1500 box. Captions sit at y ≈ 1380 (72%).
- **config.json settings** (set right after new_project):
  `"fps": 30`, `"captionStyle": {"max": 1, "y": 1380, "lower": true, "hi": "#ffffff", "size": 92, "stroke": 0.24, "strokeColor": "#000000", "font": "Nunito", "weight": 900}`
  (Rick's-Clips captions: one lowercase word at a time, white with a thick
  black outline; the `lower`/`stroke`/`font` options were added to
  `engine/ui2d.js` for video 7),
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
- **Research the animation, not just the script** (user rule, 2026-11-02):
  before building, search how the best videos in this video's visual style
  move (e.g. game feel for a game theme: hit-stop, impact frames, damage
  numbers, VS screens, battle menus) and list the techniques you'll use next
  to the shot plan.
- **Cause-and-effect chain** (video 4's first half was rebuilt for this): write
  the shot list as one chain where every shot is caused by the one before
  ("the call connects → the duplicate lines peel off the bill → they merge into
  the boss → VS screen → it attacks → you pick LIME SHIELD → the card →
  the beam hits"). If a shot could be swapped with its neighbour without
  anyone noticing, the chain is broken. Objects carry across cuts (the same
  bill line, the same card), screen direction stays consistent, and every cut
  is motivated by an action or a word.
- **No static shots**: change the angle or the subject every 1-2 s (close-up,
  low angle, insert, wide); something on screen moves in every frame.
- **Camera always moving**: every shot slowly pushes in (about 3-8% scale over
  the shot, faster on punch words). No static holds. Moves glide over about
  0.8-1 s with ease in-out (`ease.inOut`), never a 3-frame snap. Small 3-5°
  tilts for drama. Every visual reaction lands 0-3 frames before its word
  (`wordTime()`).
- **Lighting follows the story** (daylight style): bright daylight
  throughout; change the background colour per beat instead of going dark
  (sky blue for the bill, yellow for the stamp/number, cool blue for the "You
  see," comparison, green for the fix/reveal). No pure black anywhere (lift the darks); shadows purple-blue,
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
- **Pre-render technique checklist**: before the final render, go through
  every rule in this skill (script formula, hook on mute, foreshadow payoff,
  punchline + loop, title on screen, pace, safe zones, one-word captions,
  fps 30, music -10, transitions instead of hard cuts, constant camera motion,
  lighting arc, zip SFX + one riser, APP/TIP rule, new set/story shape,
  independent check). In the final message, list anything that was missed or
  only half done, honestly, before the user has to ask.

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
- **TikTok**: search phrase in the first line (TikTok search reads the
  caption, the speech and the on-screen text), a comment prompt ("Comment
  where it is 👇"), "linked in bio" (caption links aren't clickable, so the
  App Store link lives in the bio), 4-6 hashtags. Upload the cover image as
  the TikTok cover.
Every caption: the same search phrase that's spoken and on screen; a **send
line** ("Send this to someone who just got a hospital bill." Instagram counts
shares sent per view as a top signal); "built by an 11th grader"; never
accusatory. APP videos add "free to try". TIP videos mention Lime Shield
lightly in the last line only.
Save them to `social/posts/tiktok/<slug>/captions.md`.

## Stage 5: Cover photo

Copy `projects/limeshield-gauze-cover` (the new-style one-shot cover project:
config duration 2, captions off, single shot id `cover`, reuses the video's
`scenes/lib` and `scenes/sets`) to a new project and rewrite
`scenes/shots/cover.js` for this video (usually the frame-1 emphasis moment): title text in the top 30%, the key
bill moment in the middle, the buddy face and the Lime Shield pill at the
bottom. Keep the important parts between 12% and 88% of the height
(Instagram's 3:4 grid crop). Render with `--stills 1.0 --scale 1`, look at it,
fix overlaps, save as `~/Documents/LimeSheild app/LimeShield-<slug>-cover.png`,
and send it.

Add the video's row to `social/posts/tiktok/video-log.md` (slug, date,
APP/TIP, set, story shape, hook).

Finish with a short list: where the MP4 and cover are, and the order to post
(all five platforms the same evening; pin a comment answering your own question;
set the YouTube Related video link).
