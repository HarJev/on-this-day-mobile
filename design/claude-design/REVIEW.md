# Claude Design Handoff Review (2026-09-28)

Review of the two Claude Design handoffs against [DESIGN.md](../../docs/DESIGN.md)
sections 14 and 15, [QUIZ_SOURCES_NOTE.md](../QUIZ_SOURCES_NOTE.md), and the
current app. It works like
[QUIZ_SCREEN_REVIEW.md](../../docs/design/QUIZ_SCREEN_REVIEW.md) does for the
Stitch exports. The exports themselves are unedited, and this list takes
precedence over them wherever they conflict.

| Folder | Source export | Contents |
| --- | --- | --- |
| [phase-1/](phase-1/) | `design_handoff_quiz_refresh_phase_1` | Quiz hub, setup, gameplay per type, feedback, sources sheet, results, full review, components board (19 screens) |
| [phase-2/](phase-2/) | `design_handoff_today_refresh_phase_2` | Today with and without image, Event detail with and without image, loading, empty, error, notification explainer (10 screens) |

Each folder's `README.md` is the designer's handoff spec with exact values.
`screens/*.png` are 2x renders at 390x844 logical. The `design/*.dc.html` files
hold every value inline. The `presentation.html` files open offline in a browser
and include a playable Daily prototype. All copy, questions, credits, collection
counts and the two sample images are sample content.

## Verdict

Approved as the direction for the single design and typography pass. The
handoffs keep the palette, the serif/sans pairing, the two-tab root, commit-on-tap
answers, compact Daily feedback, the Quick Play explanation, sources behind one
quiet row, and the "no game-y scoring" rule. They fix the known polish issues:
zero tracking, one serif hierarchy, one back arrow, a cobalt switch,
left-aligned source rows, and a tighter vertical rhythm.

## What to adopt

- **Tokens.** Three new colours: copper dark `#7E4E2C`, cobalt tint `#EAF0F6`,
  copper tint `#F5ECE3`. Also hairline `#E3DCD0`, body soft `#3A3D42`, cobalt
  pressed `#284F78`, and scrim `rgba(23,26,31,.38)`. Radii: 12 for rows and
  buttons, 14-16 for cards and tiles, 20 for sheet tops. Screen padding is 20.
  Only the feedback panel and a dragged order row have shadows.
- **One type scale** shared by both phases (see DESIGN.md section 16). Serif is
  used for titles, questions, years and score numbers. Sans is used for body,
  answers and UI.
- **Quiz components.** Segmented progress header, lettered AnswerRow, True/False
  tiles, timeline OrderRow with years revealed after submit, sticky
  FeedbackPanel, Sources row and bottom sheet, results strip, stats row,
  "Worth revisiting" card, and the Daily "come back tomorrow" note.
- **Question-type identity.** A copper icon plus a muted label above each
  question.
- **Today and Event detail.** Featured card with the year at serif 40 (56
  without an image), copper hairline, "Read the full story" link. "Also on this
  day" and "Recent days" rows use a fixed year/date column. The detail image is
  shown uncropped, with a caption credit. The Sources disclosure starts
  collapsed. The quiz link is a 64px row.
- **States.** Layout-matching skeletons, the error card with "Try again", the
  detail error with "Back to Today", and the notification explainer sheet.
- **Motion.** The motion table as written, with 100 ms opacity or no animation
  under reduced motion.

## Corrections (written rules win)

1. **Small copper text fails contrast.** Copper `#A66A3F` is 3.99:1 on paper and
   4.34:1 on ivory. Text under 18pt must use copper dark `#7E4E2C` (6.85:1 on
   ivory, 5.97:1 on copper tint). This covers the "Worth revisiting" eyebrow, tag
   lines, and any copper label. Copper stays fine for icons, rules and borders.
2. **Pre-answer image credit.** Keep the quiet "Image credit after answering"
   line that the app shows today (`QuizQuestionImage.pendingCreditMessage`) and
   that DESIGN.md section 14 requires. The handoff's default of showing nothing is
   not adopted. After commit, use the handoff's caption under the image. Full
   review uses the collapsed "Image credit" row.
3. **Answer leakage in the image itself.** The sample portrait still shows its
   printed caption ("George Washington", "Gilbert Stuart") at the edges. If a
   real quiz image carries printed text like this, it gives the answer away. The
   renditions should be checked and cropped in the backend image pipeline. This
   is an editorial fix, not a UI one.
4. **Image answer grid.** Use the 2x2 grid only when every option fits in two
   lines at the current text scale. Otherwise fall back to the single-column
   AnswerRow list. Options must never truncate.
5. **Hub "Done" state.** The app's label "Practice again" stays, rather than
   "Replay as practice", and so does the current practice/official copy.
6. **Recent days navigation.** Rows open that day's featured Event detail, as
   shipped in mobile PR #5 and required by workplan A3. The handoff's "opens
   that day's Today view" would make a date browser, which A3 rules out. The
   "Today" label replaces the weekday on the current date, per the handoff.
7. **Quiz link target.** Keep the existing wiring from mobile PR #5
   (`EventDetailScreen.onTestWhatYouLearned`). Only restyle it as the 64px row.
   Once workplan A2 adds related questions, section 15's rule applies: show the
   link only when a related question exists.
8. **Empty-day state** (`07_today_empty.png`) is designed but parked. The owner
   deferred the empty-day fallback on 2026-09-28. Use the styling when that
   work resumes.
9. **Notification explainer.** Adopt the sheet and the copy. Push delivery
   stays deferred (no paid Apple developer account). The app already defers the
   OS prompt, so this is restyling only.
10. **Timers.** The header shows "Total time" for Daily, "Question time" for
    timed Quick Play, and nothing when untimed, which matches section 14. Quick
    Play setup shows the app's real per-type limits from `quiz_rules.dart`
    (20 s choice/true-false, 30 s image, 45 s ordering), or no number. Never
    show an invented single value.
11. **Error colour.** Keep copper for "incorrect" states. Material's red
    (`0xFFB3261E`) must not show on gameplay or Today error states. Use the
    handoff's copper-tint error card.
12. **Fonts.** The handoff uses Source Serif 4 and Public Sans as stand-ins. The
    app currently asks for Georgia, with system sans. Georgia is missing on
    Android, where the fallback serif differs. Decision for the pass: bundle
    Source Serif 4 and Public Sans as app assets (both SIL OFL, free, no network
    font loading) so iOS and Android match. Revert to Georgia plus system sans
    if the owner prefers a smaller app.

## Missing or implied states

- Large text scale for every component. The handoff says rows grow and header
  items wrap, but shows no render of it. Verify on device.
- Image preparation, retry, and unsaved-result states keep the section 14 rules
  and inherit the new error card styling.
- Abandon-confirmation dialog: restyle with the new button specs, no layout
  change.
