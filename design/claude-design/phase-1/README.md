# Handoff: On This Day — Quiz visual refresh (Phase 1)

## Overview
Visual refresh of the Quiz tab of "On This Day", a Flutter iOS/Android daily-history app. This is an improvement pass, not a redesign: identity, layout logic and navigation stay the same. Goals: less flat, more varied and more satisfying quiz sessions: a distinct treatment per question type, a clear calm answer reveal with context (year/date), a segmented progress header, sticky footers, a timeline metaphor for ordering, and a results summary with a per-question strip. No game-y scoring (no points, streaks, medals, confetti, leaderboards).

Phase 2 (Today, Event detail, empty/error/notification states) is **not** in this package.

## About the design files
The files in this bundle are **design references built in HTML**. They show the intended look and behaviour; they are not production code to copy. Recreate them in the existing **Flutter** codebase using its established widgets, theme and patterns (ThemeData / ColorScheme / TextTheme extensions, existing router, existing quiz state management).

- `Quiz Refresh - presentation.html` — self-contained, works offline. Open it in a browser. It contains, in order: notes and assumptions, a **playable Daily Challenge prototype** (hub → setup → 5 questions, one of each type → results), static mockups for every screen and state, a components board, and motion notes.
- `screens/*.png` — 2× renders of every mockup (390×844 logical px each; full review is a tall scrolling capture).
- `design/` — editable source (`Quiz Refresh.dc.html` plus component files `AnswerRow`, `TFTile`, `OrderRow`, `QuizHeader`, `FeedbackPanel`). Each is plain HTML with inline styles. **Read these for exact values**: every px, colour and font weight is inline on the element. `support.js` is only the preview runtime and is not relevant to the implementation.

## Fidelity
**High fidelity.** Final colours, type scale, spacing, radii and states. Match them closely. Sizes are in logical px (= Flutter logical pixels). All copy in the mockups (questions, explanations, collection names, source titles, image credit) is **sample content**. Use real data from the app.

## Global rules (from the brief, keep)
- Two-tab bar (Today, Quiz) on root screens only. Setup, gameplay, results and review get a back button and no tab bar.
- No profile/search/settings icons in the masthead.
- Touch targets ≥ 48pt. Never show state by colour alone: every state has an icon **and** text.
- Question text and answers always wrap fully. Never truncate or ellipsize. Must work at large accessibility text sizes: rows grow in height, and header items wrap (see QuizHeader).
- Respect reduced motion (`MediaQuery.disableAnimations`).
- Letter spacing: normal everywhere.

## Design tokens

### Colours
| Token | Hex | Use |
|---|---|---|
| paper | `#F7F3EA` | screen background |
| ivory | `#FFFDF7` | cards, rows, sheets, tab bar |
| ink | `#171A1F` | primary text, "done" progress segments |
| muted | `#62656A` | secondary text, inactive icons |
| cobalt | `#2F5F8F` | primary buttons, years/dates, links, correct state, current progress segment |
| cobalt pressed | `#284F78` | primary button pressed |
| copper | `#A66A3F` | type icons, hairline rules, incorrect-state borders/fills |
| copper dark | `#7E4E2C` | small text/icons on copper tint (contrast) — **new** |
| stone | `#D8D1C6` | borders, upcoming progress segments, grabbers |
| fill | `#EBE3D6` | subtle fills, dividers inside cards, skipped/unanswered cells |
| hairline | `#E3DCD0` | dimmed row borders |
| cobalt tint | `#EAF0F6` | correct row/tile/cell fill, active tab pill — **new** |
| copper tint | `#F5ECE3` | incorrect row/tile/cell fill — **new** |
| scrim | `rgba(23,26,31,.38)` | behind bottom sheets |

### Typography
Stand-ins: **Source Serif 4** (serif) and **Public Sans** (sans). If the app already ships different families, keep the app's and map these sizes onto them.

| Role | Font | Size / line-height | Weight |
|---|---|---|---|
| Masthead "On This Day" | serif | 22 | 600 |
| Page title ("Quiz", "Build a round") | serif | 34 / 1.1 (hub), 30 / 1.15 (setup) | 600 |
| Card headline (Daily date) | serif | 26 / 1.15 | 600 |
| Nav bar title | serif | 17 | 600 |
| Question (idle) | serif | 23 / 1.28 | 500 |
| Question (answered, compressed) | serif | 20 / 1.28 | 500 |
| Feedback title | serif | 22 / 1.2 | 600 |
| Result score | serif | 60–64 / 1 | 600, then "of 5" serif 26–28 muted 400 |
| Stat numbers | serif | 22 | 600 |
| Year on order rows | serif | 17 / 1.2 | 600, cobalt |
| Body / answers | sans | 16 / 1.35 | 400 (600 when correct) |
| Explanation | sans | 15 / 1.5 | 400 |
| Secondary | sans | 14–15 / 1.45 | 400, muted |
| Labels, eyebrows, tags | sans | 12–13 | 600 |
| Tab label | sans | 12 | 500 (600 active) |
| Timer | sans | 14, tabular figures | value 600 |

### Spacing, radii, shadows
- Screen horizontal padding **20**. Vertical rhythm in 8/10/12/14/16 steps (see source).
- Radii: rows and buttons **12**; cards, tiles and length selectors **14–16**; sheets and feedback panel **20** (top corners only); pills **999**; image mat **6**.
- Primary button: height 52, radius 12, cobalt, ivory text 16/600. Secondary: height 48, 1px stone border, transparent, cobalt text 15/600. Text button: height 48, cobalt 15/600.
- Shadows: feedback panel `0 -8px 24px rgba(23,26,31,.06)`; dragged order row `0 10px 24px rgba(23,26,31,.14)`. Nothing else has a shadow.
- Icons: Material Symbols Outlined (Flutter `Icons.*_outlined` or the `material_symbols_icons` package). Filled variants are used for `check_circle`, `verified`, `radio_button_checked` and the active `quiz` tab.

### Question-type identity
Each type has a copper icon (18) and a 13/600 muted label above the question:
| Type | Icon | Label | Answer treatment |
|---|---|---|---|
| Multiple choice | `format_list_bulleted` | Multiple choice | vertical list of lettered AnswerRows |
| True/false | `rule` | True or false | two equal TFTiles side by side |
| Image | `imagesmode` | Identify the image | matted image + 2×2 grid of AnswerRows |
| Ordering | `swap_vert` | Put in order | OrderRows on a vertical timeline rail |

## Components (see `design/*.dc.html` and `screens/19_components.png`)

### QuizHeader
- Row 1 (52): 48×48 back button (`arrow_back`) · centred serif 17/600 mode title ("Daily Challenge" / "Quick Play") · 48 spacer.
- Row 2 (min 28, padding 0 20, wraps at large text): left "Question {n} of {total}" 14/600 (no wrap); right timer in cobalt: `timer` icon 17 + label + value 600, tabular. Daily: "Total time 01:32". Timed Quick Play: "Question time 00:18". Untimed: no timer.
- Row 3: segmented bar, one segment per question, gap 3, height 3, radius 2, padding-top 6. Done = ink, current = cobalt, upcoming = stone. Bottom padding 10.

### AnswerRow (MC + image)
Min height 56, padding 12/14, gap 12, radius 12. Left: 28px circular letter badge (A–D). Label fills the rest and wraps.
| State | Fill | Border | Badge | Label | Tag line (13/600) |
|---|---|---|---|---|---|
| idle | ivory | 1 stone | 1 stone ring, letter muted | ink 400 | — |
| pressed | `#F1ECE2` | 1.5 ink | 1.5 ink ring | ink | — |
| correct | cobalt tint | 2 cobalt | cobalt fill, white `check` | ink 600 | cobalt "Your answer" or "Correct answer" · optional muted note (e.g. "August 22, 1485") |
| wrong (your pick) | copper tint | 2 copper | copper fill, white `close` | ink 400 | copper-dark "Your answer" |
| dim | transparent | 1 hairline | hairline ring, letter muted | muted | — |
When the border goes to 2px, reduce padding by 1px so the content doesn't shift.

### TFTile
Min height 140, radius 16, centred column: 52px icon circle (`check` for True, `close` for False) plus the serif 24/600 label. The same states as AnswerRow (idle/correct/wrong/dim), with a tag line under the label.

### OrderRow
- Left rail column 32 wide. A 2px stone line runs through all rows (broken above the first node and below the last). The node is a 32px circle, top offset 12.
- Idle: node paper fill + 1.5 stone ring + serif 15 position number. Card: ivory, 1 stone, radius 12, min 56. `drag_indicator` handle (20, muted), label 15/1.35, then two 40×48 icon buttons `arrow_upward` / `arrow_downward` (first row's up and last row's down disabled at 30% opacity, and they must be semantically disabled).
- Lifted (dragging): card border 1.5 ink, shadow, translateY(-2) scale 1.01. Node ink fill with white number.
- After submit, right: node cobalt fill + white `check`. Card cobalt tint, 1.5 cobalt. Top line: year (serif 17/600 cobalt) and right-aligned "In place" 12/600 cobalt. Then the label.
- After submit, wrong: node paper + 2px copper ring + copper-dark `close`. Card ivory, 1.5 copper. Year in cobalt, right tag "Belongs 3rd" 12/600 copper-dark.
- Small "Earliest" (`north`) and "Latest" (`south`) 12/600 muted labels above and below the list.
- Up/down buttons disappear after submit.

### FeedbackPanel (sticky footer)
Ivory, 1px stone top border, top radius 20, padding 18/20/30, gap 12, shadow as above. The content area above it shrinks and scrolls.
- Header: 36px icon circle + serif 22/600 title + optional 13 muted sub-line.
  - correct: cobalt fill, white `check`, "Correct"
  - incorrect: 2px copper ring, copper-dark `close`, "Incorrect" (ordering sub-line: "2 of 4 in place")
  - time's up: 2px ink ring, `hourglass_bottom`, "Time's up", sub "No answer recorded"
  - skipped (image only): fill-colour circle, `redo`, "Skipped"
- Answer block: 12/600 muted label ("Answer" / "Correct order") + 16/600 answer + " · context" muted 400 (year or date).
- **Daily**: stop there, then Continue. **Quick Play**: add the explanation (15/1.5), then a 48px "Sources (n)" row (`menu_book`, `chevron_right`, hairline top/bottom borders) that opens the Sources bottom sheet.
- Button: primary "Continue" + `arrow_forward`. On the last question it reads "See results".

### Sources disclosure
- A single quiet 48px row: `menu_book` 19 muted · "Sources (n)" 15/500 · chevron. Never show source links up front.
- Full review: expands in place (`expand_more` ↔ `expand_less`). Links are listed indented 29px, each min 48, 14px title + cobalt `open_in_new` 18.
- Quick Play feedback: opens a bottom sheet (`screens/15_sources_sheet.png`): grabber 36×5, serif 22 "Sources", close 48×48, rows min 64 with 16/600 publisher + 13 muted title + cobalt `open_in_new`.

### Image credit (image questions)
- Before answering: **nothing is shown** about the credit (no placeholder). The prototype has a tweak to show "Image credit after answering" (lock icon, 13 muted) if you ever want it; the default is off.
- After answering or skipping: reveal the credit as a **caption** directly under the image, 12/1.4 muted, fading in with the feedback panel. Alternative (tweak): a collapsed 44px "Image credit" row (`photo_camera`, `expand_more`). In Full review the credit uses the collapsed row pattern.
- Image frame: ivory mat, 1px stone border, radius 6, padding 8–10, image centred with `BoxFit.contain` (never crop portraits). Height ≈ 250 idle, ≈ 170 when the feedback panel is open.

### Results pieces
- Strip cells: height 44–48, radius 10. Correct: cobalt tint, 1px cobalt, `check`. Incorrect: copper tint, 1px copper, copper-dark `close`. Unanswered: fill colour, muted `remove`. Daily (5) is one row, with the type icon (15 muted) under each cell. 10 or more questions use a 5-column grid. A legend (icon + word) is shown when there's no type row. Each cell opens that question in Full review.
- Stats: 3-column grid between stone hairlines: serif 22 number + 13 muted label (Answered / Correct / Unanswered).
- Status line: official = filled `verified` cobalt + "Official Daily result" 15/600 (+ "Total time 01:04" right, muted). Practice = `history_edu` muted + "Practice round" + "Not an official result".
- "Worth revisiting" card: ivory card, copper 13/600 eyebrow with `bookmark` + "Worth revisiting · Question n". Serif 17 short title, 14 explanation excerpt, cobalt "Open in review" link. Pick the first incorrect or unanswered question that has an explanation. Hide the card if there's none.
- Daily only: a "come back" note on a fill background, radius 12: `event_upcoming` + "A new Daily Challenge arrives tomorrow."

## Screens (PNG in `screens/`)
1. **01 Hub, fresh**: masthead with a bottom hairline. "Quiz" title + subtitle. Daily card: eyebrow `today` "Daily Challenge" + "Not played yet"; date as the serif headline; description; four type chips (pill, paper fill, fill-colour border, copper icon); copper hairline at 55% opacity; primary "Choose challenge →". Quick Play card: eyebrow `tune`, description, secondary "Choose a round". Tab bar: ivory, top hairline, 60 tall + safe area. The active tab has a 56×28 cobalt-tint pill behind a filled icon and a cobalt 600 label.
2. **02 Hub, Daily done**: eyebrow shows filled `check_circle` "Done". Headline "3 of 5 correct" + "Official · 01:04". 5-cell strip. Tomorrow note. Buttons "Review answers" (primary) + "Replay as practice" (secondary). *Assumes replay-as-practice already exists; drop it if not.*
3. **03 Daily setup**: back nav. Date eyebrow (cobalt), "Today's challenge", description. "Length" label + three 88-tall tiles 5/10/20. Selected = cobalt tint, 2px cobalt, filled `check_circle` top-right, cobalt "questions". "Question types in today's set" 2×2 list. Official-result card (filled `verified` + explanation). "One clock for the whole set" line. Sticky "Start challenge".
4. **04 Quick Play setup**: "Build a round". Collection row (64, `collections_bookmark`, "Mixed / Questions from all 9 collections", "Change" + chevron) opens the sheet. Questions 5/10/20 tiles (64 tall). Timer row with the text "On" plus the switch (the knob holds a check icon, so state isn't colour-only). Sticky "Start round". Don't invent a seconds-per-question value; show the app's real one if it has one.
5. **05 Collection sheet**: scrim + sheet with top radius 20. Radio rows (selected = filled `radio_button_checked` cobalt + "Selected" text), min 52–60, hairline dividers.
6. **06 Multiple choice** (Daily, total time), **07 True/false** (timed Quick Play, question time), **08 Image** (untimed, no timer, "Skip question" text button footer), **09 Ordering** (Daily; sticky footer "Drag rows or use the arrows" + "Submit order"). MC and TF show a "Tap an answer to lock it in" hint (`touch_app`, 13 muted), because a tap commits immediately.
7. **10–15 Feedback**: correct Daily · incorrect Quick Play (explanation + sources) · time's up · skipped image (Daily, "See results") · ordering submitted · sources sheet. When answered, the type label may be dropped and the question shrinks to 20 so the answers stay visible above the panel.
8. **16 Daily results (official)**, **17 Quick Play results (practice)**: layout as described in Results pieces. Footer: "Review answers" (flex 2, `fact_check`) + "Done" / "New round" (flex 1, secondary).
9. **18 Full review**: summary line, then one ivory card per question (radius 16, padding 18). Header: "Question n", type icon + label, and a right-aligned status pill (Correct = cobalt tint/cobalt; Incorrect = copper tint/copper-dark; Skipped = fill/ink), always with an icon. Serif 19 question. Then per type:
   - MC/TF: "Your answer" (plus "Correct answer" when wrong).
   - Ordering: the correct order as rows of year (serif 16 cobalt, 48 col) | label | your placement ("✓ 1st" or "✕ You: 4th").
   - Image: thumbnail 88 tall + correct answer.
   Then the explanation, then the Image credit / Sources (n) disclosures.

## Interactions & behaviour
- MC, TF and image: **tap commits and locks immediately.** There is no confirm step. After commit, all options become non-interactive.
- Ordering: long-press drag to reorder (Flutter `ReorderableListView` with a custom proxy decorator for the lifted style), or the up/down buttons. "Submit order" commits. After submit, reveal years and marks.
- Image: "Skip question" commits as skipped. The credit is revealed after commit.
- Daily timer counts down the total for the set. Quick Play timed counts down per question; at 0 → Time's up feedback, recorded as unanswered.
- Continue → next question. On the last question → Results.
- Results "Review answers" → Full review. Strip cells deep-link to that question's card.
- Semantics: announce the feedback title + answer when the panel appears. Each OrderRow button has a label ("Move up" / "Move down"). The switch exposes on/off.

## Motion
| Moment | Spec |
|---|---|
| Commit answer | row fill/border 120 ms; badge letter → icon crossfade 160 ms with scale 0.9→1, ease-out, no overshoot; other rows → dim over 200 ms; light haptic |
| Feedback panel | slide up 16 px + fade, 220 ms, cubic-bezier(.2,.7,.2,1) |
| Ordering | lifted row shadow + 1% scale; neighbours slide 180 ms; arrow-button swaps animate identically; selection haptic per swap; on submit years fade in per row with 40 ms stagger, then node marks |
| Next question | crossfade + 12 px leftward shift, 200 ms; current progress segment fills stone→cobalt over 240 ms, previous settles to ink |
| Results | strip cells reveal L→R, 30 ms stagger; score appears fully formed (no count-up) |
| Reduced motion | no translation/scale/stagger; 100 ms opacity or instant |

## State (per session)
`mode` (daily | quickPlay), `isOfficial`, `length`, `collectionId`, `timed`, `index`, `timer` (total or per-question), `order[]` (ordering), `pickedIndex | skipped | timedOut`, `submitted`, `results[]` ({questionId, outcome: correct | incorrect | skipped | unanswered, userAnswer}). The hub needs `todayDailyResult?` to switch between fresh and done.

## Assets
- `design/assets/portrait-sample.png` — cropped from the app's own screenshot, for the mockup only. Use the question's licensed image and credit from app data.
- Icons: Material Symbols Outlined.
- No new illustrations. Never invent imagery or historical content.

## Files
- `Quiz Refresh - presentation.html` — offline presentation + playable prototype
- `screens/01…19*.png` — renders
- `design/Quiz Refresh.dc.html` — main source (screens, prototype logic in the script at the bottom)
- `design/QuizHeader.dc.html`, `AnswerRow.dc.html`, `TFTile.dc.html`, `OrderRow.dc.html`, `FeedbackPanel.dc.html` — component sources with all states
