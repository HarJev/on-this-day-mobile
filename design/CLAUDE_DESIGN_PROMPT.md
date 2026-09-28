# Claude Design Prompt: Refresh the Quiz, Then the Rest of the App

## How to run it

Claude Design is separate from the Claude project threads: open it on
claude.ai, start a new design, paste the prompt below, and attach the
screenshots listed under "Attach these". It only sees what you paste and
attach. Ask for Phase 1 first, give feedback in the same design until you are
happy, then ask it to continue with Phase 2. Export the screens as PNGs and
drop them into `design/claude-design/phase-1/` and `phase-2/`; a Claude thread
then writes the review and does the single implementation pass.

Copy everything in the box below into Claude Design. Attach the screenshots
listed under "Attach these" first. The prompt is self-contained; Claude Design
does not need access to this repository.

---

```text
You are refreshing the visual design of "On This Day", a Flutter iOS/Android
app. This is an improvement pass, not a redesign: keep the identity, layout
logic and navigation, and make it look and feel more polished and more
engaging. Work in two phases and stop after Phase 1 for review.

WHAT THE APP IS
A calm, editorial daily history app. The loop is:
Today -> featured historical event -> learn -> read sources -> daily quiz ->
come back tomorrow. It should feel like a modern history magazine or a museum's
daily note: trustworthy, curated, readable. Not a trivia game, not an
encyclopedia, not a dashboard, not a Material Design demo.

KEEP (non-negotiable)
- Palette: warm paper #F7F3EA background, soft ivory #FFFDF7 surfaces, deep ink
  #171A1F text, muted gray #62656A secondary text, archival cobalt #2F5F8F for
  years/dates/links, muted copper #A66A3F used sparingly for rules and accents,
  pale stone #D8D1C6 borders, soft warm gray #EBE3D6 fills.
- Type: an elegant serif for titles and questions, a clean sans-serif for
  body, answers and UI. Letter spacing stays normal.
- Navigation: a compact two-tab bar (Today, Quiz) on the two root screens only.
  Gameplay, results, review and event detail sit above it with a back button.
- No profile, search or settings icons in the masthead. No parchment, scrolls,
  wax seals, heavy sepia, loud red, neon, medals, confetti, streak flames,
  leaderboards, speed bonuses or points systems.
- Accessibility: 48pt touch targets, state never shown by colour alone (use
  icon + text too), readable at large text sizes, reduced-motion respected,
  question text and answers always wrap fully (never truncate).

FIX THESE KNOWN TYPE AND POLISH ISSUES EVERYWHERE
- Body text currently uses Material's default letter spacing and reads as
  typewritten; use normal (zero) tracking.
- Three different serif treatments are in use (bold titles, regular quiz
  prompts, bold review prompts). Define one hierarchy: bold serif for screen
  and event titles, semibold serif for question prompts, same in review.
- Back buttons mix an arrow and an iOS chevron; use one.
- Switches render bright system green; use archival cobalt.
- Short source rows are centred while wrapped ones are left-aligned; always
  left-align.
- Several screens leave the bottom half empty on tall phones; tighten the
  vertical rhythm.

PHASE 1 - THE QUIZ (the priority)
The owner's feedback: going through the quiz feels boring. Screens are correct
but visually flat - long stretches of plain text on paper, identical rows, and
little sense of progress, reward or variety between question types.

Quiz screens to redesign (states in brackets):
1. Quiz hub (fresh; after today's Daily is done).
2. Daily Challenge setup (5/10/20 selector, date, official status).
3. Quick Play setup (count, collection picker sheet, timed on/off).
4. Gameplay, one design per question type:
   - multiple choice (4 options, tap commits and locks immediately),
   - true/false,
   - image identification (image + 4 options; image credit hidden until
     answered, a quiet "Image credit after answering" placeholder instead),
   - chronological ordering (4 draggable rows with up/down buttons, then
     "Submit order").
   Include the compact header: thin progress bar + "Question 3 of 10", and the
   timer ("Total time 01:32" in Daily; "Question time 00:18" in timed Quick
   Play; none when untimed).
5. Answer feedback: correct, incorrect, time's up, skipped (image only). Daily
   feedback is compact (result + correct answer + Continue). Quick Play
   feedback adds the explanation.
6. Results: correct/total, percentage, answered/correct/unanswered, official
   vs practice.
7. Full review: every question with the user's answer, correct answer,
   explanation, and sources.

Ideas to explore (pick what works, keep it tasteful):
- Give each question type a subtle visual identity (an icon, a small label,
  a distinct answer-row treatment for ordering vs choice) so sessions feel
  varied.
- Make the moment of answering satisfying: a clear, calm correct/incorrect
  reveal (ink + cobalt/copper accents, a short non-bouncy transition), and show
  the correct answer with a little context (for example the year).
- Better rhythm: less dead space above the question, answers visible without
  scrolling on a normal phone, a sticky footer for Continue / Submit order.
- Chronological ordering: make it feel like placing events on a timeline
  (year revealed on each row after submitting, correct positions marked).
- Results: a more rewarding summary without game-y scoring - for example a
  compact per-question strip of right/wrong, the best explanation to revisit,
  and a gentle "come back tomorrow" note for Daily.
- Use imagery where the question already has a licensed image; never invent
  images or historical content. Placeholder text in mocks is fine, but label
  it as sample content.
- Sources: do NOT show source links at the forefront. Collapse them behind one
  quiet tappable row such as "Sources (4)" that expands in place (Full review)
  or opens a bottom sheet (Quick Play feedback). Same for image credits after
  answering.

Deliver for Phase 1: mobile mockups (about 390x844) for every screen and state
above, a short component list (answer row states, progress header, feedback
panel, sources disclosure, results summary), and notes on motion. Then stop.

PHASE 2 - THE REST OF THE APP (after Phase 1 is approved)
Apply the same refined system to:
1. Today: masthead with app name and date; featured event (year, title,
   summary, optional image with a quiet credit line: creator and licence, full
   source behind a tap) as the clear editorial pick; "Also on this day" list of
   3-4 events; a "Recent days" section showing the featured event from each of
   the previous six dates (date, year, title), tappable into Event detail. It
   should invite a quick look back without becoming an archive or calendar.
2. Event detail: back, year/date, title, optional image with credit, 2-3
   sentence description, sources (same quiet disclosure), and a compact
   "Test what you learned" link into the quiz.
3. Empty, loading and error states for both, and the in-app notification
   explainer ("Enable daily history reminder" / "Not now").
Keep the featured event the strongest element on Today. Improve typography,
spacing, image framing and the list rows; don't add features beyond the ones
listed here.

Deliver for Phase 2: mockups for Today (with and without a featured image,
with the Recent days section),
Event detail (with and without image), and the empty/error/notification
states, plus any component changes.
```

---

## Attach these

From this repository:

- `docs/design/home.png`, `docs/design/event_details.png` (current canonical Today
  and Event detail direction)
- `docs/design/quiz_*.png` (earlier quiz proposals; useful for structure only)
- `design/references/quiz_full_review_sources_2026-09-28.png` (the sources problem)

From the workspace walkthrough (`../review/screens/ios-2026-09-26/`), the
current real app, for example:

- `01_today.png`, `02_event_detail.png`
- `03_quiz_hub_fresh.png`, `04_daily_setup.png`, `24_quickplay_setup.png`
- `06_daily_q1_ordering.png`, `09_daily_q2_multiple_choice.png`,
  `11_daily_q4_true_false.png`, `13_daily_q5_image.png`
- `08_daily_q1_correct_feedback.png`, `10_daily_q2_wrong_feedback.png`
- `16_daily_results.png`, `18_daily_review.png`

## After Claude Design returns

1. Save exports under `design/claude-design/phase-1/` (and `phase-2/`) with
   descriptive filenames, like `docs/design/` does.
2. Review them against DESIGN.md sections 14 and 15 and
   [QUIZ_SOURCES_NOTE.md](QUIZ_SOURCES_NOTE.md). Write corrections in a short
   `REVIEW.md` next to the exports, the way `docs/design/QUIZ_SCREEN_REVIEW.md`
   does for the Stitch exports.
3. Only then update DESIGN.md and implement. Written product rules win over
   anything a mockup shows (invented facts, timers, scoring, or credits).
