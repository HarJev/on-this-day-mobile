# Handoff: On This Day — Today & Event detail refresh (Phase 2)

## Overview
Phase 2 of the visual refresh for the Flutter iOS/Android app "On This Day". It applies the Phase 1 quiz system (see `design_handoff_quiz_refresh`) to Today, Event detail, empty/loading/error states and the in-app notification explainer. The featured event stays the strongest element on Today. **No new features**: the work is typography, spacing, image framing and list rows.

## About the design files
The files are **HTML design references**, not production code. Recreate them in the existing Flutter codebase using its widgets, theme and patterns.
- `Today Refresh - presentation.html` — self-contained and works offline. It has notes, all mockups, and a component-changes list. On the detail screen, "Sources (2)" opens and closes when tapped.
- `screens/*.png` — 2× renders (390×844 logical; 01 and 04 are tall full-scroll captures).
- `design/Today Refresh.dc.html` — editable source. Every value is inline on its element, so read it for exact numbers. `support.js` is only the preview runtime.

## Fidelity
**High fidelity.** Match colours, type, spacing and radii. Recent-days titles, image credits and source titles are **sample content**; use real app data. The painting is a low-resolution crop from an app screenshot.

## Design tokens
Identical to Phase 1. Key values:
- Colours: paper `#F7F3EA`, ivory `#FFFDF7`, ink `#171A1F`, muted `#62656A`, body-soft `#3A3D42`, cobalt `#2F5F8F`, copper `#A66A3F`, copper-dark `#7E4E2C` (small copper text), stone `#D8D1C6`, fill `#EBE3D6`, cobalt-tint `#EAF0F6`, copper-tint `#F5ECE3`, scrim `rgba(23,26,31,.38)`.
- Fonts: serif (Source Serif 4 stand-in) for titles and years; sans (Public Sans stand-in) for body and UI. Letter spacing is normal.
- Radii: cards 16, rows/buttons 12, quiz-link row 14, detail image 8, mat 6, sheet 20 (top).
- Screen padding 20; the gap between Today sections is 32.
- Icons: Material Symbols Outlined.

## Screens
1. **Today, with image** (`01`)
   - **Masthead:** 56 tall, 3-column grid (72 · 1fr · 72). Serif 22/600 "On This Day" centred, "Aug 22" 14/600 on the right, stone hairline below.
   - **Eyebrow row:** "Featured" 13/600 cobalt on the left, "Saturday, August 22" 13 muted on the right.
   - **Featured card:** ivory, 1px stone, radius 16, overflow clipped.
     - Image full-bleed at aspect 16:9.5, `BoxFit.cover`. Tweak alternative: matted, with 14px inset + paper mat, 1px fill border, radius 6, padding 10.
     - Body padding 18/20/20, gap 10:
       - year serif 40/600 cobalt + place 13/600 copper-dark
       - copper hairline at 55% opacity
       - title serif 28/1.15/600
       - summary 16/1.5 `#3A3D42`
       - "Read the full story" 15/600 cobalt + `arrow_forward`, row min 40. The whole card is tappable.
   - **"Also on this day"** (3–4 items):
     - Header: serif 22/600 with a 32×2 copper bar 8px below.
     - Rows: grid 52 · 1fr · 22, gap 12, min 60, padding 10/0, 1px stone bottom border. Year serif 17/600 cobalt, title 16/1.4 (wraps, never truncates), `chevron_right` muted.
   - **Recent days** (optional; today + previous 6):
     - Same header.
     - Rows: grid 64 · 1fr · 22. The date column is "Aug 21" 14/600 cobalt over a 12 weekday in muted text; the current day shows "Today" 12/600 in ink instead.
     - Title 15/1.4, prefixed with "1911 · " in muted text.
   - **Tab bar:** Today active (cobalt-tint 56×28 pill, filled icon, 600 label).
2. **Today, no image** (`02`): the same card without an image. Padding 22/20/20, gap 12, year grows to serif 56, title to serif 30.
3. **Notification explainer** (`03`):
   - Bottom sheet over Today with the scrim behind. Grabber 36×5 stone.
   - 48px cobalt-tint circle with a `notifications` icon.
   - Title serif 26/1.15 "A daily note from history". Body 15/1.5: "One notification a day with the featured event. You can turn it off at any time in Settings."
   - Preview card: paper fill, 1px fill border, radius 14. App tile 36 ink/radius 9, "On This Day · now", "**1485 ·** Richard III…". Below it, "Preview" 12 muted.
   - Buttons: primary 52 "Enable daily history reminder", then text button 48 "Not now".
   - Show the sheet before the OS permission prompt. Only the primary button triggers the OS prompt.
4. **Event detail, with image** (`04`):
   - Nav: 48×48 back, serif 17/600 "On This Day" centred, no tab bar.
   - Header: year serif 22/600 cobalt + "August 22" 14 muted; copper hairline at 55%; title serif 32/1.15/600.
   - Image: full width at its natural aspect (never crop on detail), radius 8, 1px stone border. Matted alternative as on Today.
   - **Credit caption** directly below the image, 12/1.4 muted. No disclosure.
   - Description: 2–3 sentences, 17/1.6 ink, paragraphs 12 apart.
   - Sources disclosure:
     - One 52px row between stone hairlines: `menu_book` 19 muted, "Sources (n)" 15/500, `expand_more`/`expand_less`.
     - Expands in place. Links are indented 29px, each min 52, bottom border fill: publisher 15/600 + title 13 muted + cobalt `open_in_new` 18.
     - Collapsed by default.
   - Optional quiz link: 64px ivory row, 1px stone, radius 14. 40px cobalt-tint circle with a `quiz` icon, "Test what you learned" 16/600, "Opens the quiz" 13 muted, chevron.
5. **Event detail, no image** (`05`): the same screen without the image block.
6. **Today loading** (`06`):
   - Skeleton that mirrors the real layout: image block, year, hairline, two title lines, summary line, section header, list lines.
   - Blocks are fill `#EBE3D6`, radius 6, pulsing in opacity 1 → 0.6 over 1.2 s (static under reduced motion).
   - Content fades in over 150 ms. Give the region a semantics label: "Loading today's history".
7. **Today empty** (`07`):
   - Ivory card with a **dashed** stone border, radius 16, padding 28/22.
   - 44px fill circle with a `calendar_today` icon.
   - Title serif 24 "Nothing for August 22 yet". Body 15 "Today's events aren't ready. Earlier days are below."
   - Recent days list below the card.
8. **Today error** (`08`): ivory card, solid border. 44px copper-tint circle with a copper-dark `cloud_off` icon. "Couldn't load today's history" / "Check your connection and try again." / primary "Try again" with a `refresh` icon.
9. **Detail loading** (`09`): if the year and title are passed from the list, show them at once; skeleton for the image and three body lines.
10. **Detail error** (`10`): as 08, with `error` icon, "This event couldn't be loaded", primary "Try again" + secondary 48 "Back to Today".

## Interactions
- Featured card and every list row open Event detail. Recent-day rows open that day's Today view.
- The sources row toggles in place. The expand motion is a 180 ms size + fade (instant under reduced motion).
- The quiz link navigates to the Quiz tab / Quick Play setup (existing route).
- Notification sheet: "Enable" → OS prompt → dismiss. "Not now" → dismiss and remember the choice.
- All touch targets ≥ 48. All text wraps at large text sizes, and the list-row grid keeps the year column fixed.

## Assets
- `design/assets/bosworth-painting.png` — for the mockup only; use the event's licensed image and credit.
- Icons: Material Symbols Outlined.

## Files
- `Today Refresh - presentation.html`, `screens/01…10*.png`, `design/Today Refresh.dc.html`
- Shared components (sources disclosure, buttons, tab bar, tokens) are specified in the Phase 1 handoff.
