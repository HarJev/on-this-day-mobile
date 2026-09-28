# Mobile Note: Quiz Sources Behind a Tap

**Status:** Owner direction (2026-09-28), not yet implemented  
**Affects:** `quiz_full_review_screen.dart`, `widgets/quiz_answer_feedback.dart`,
`widgets/quiz_ordering_feedback.dart`, `widgets/quiz_source_row.dart`,
`widgets/quiz_review_external_link.dart`

## What changes

Source links should not sit at the forefront of quiz feedback and review.
Today every source renders as a full-width cobalt link row directly under the
explanation, so a question with four sources ends in four large links (see
[references/quiz_full_review_sources_2026-09-28.png](references/quiz_full_review_sources_2026-09-28.png)).
The explanation and the correct answer should be the last thing the eye lands
on, not a stack of links.

Replace the inline rows with one quiet, tappable control:

- A single row such as `Sources (4)` with a trailing chevron or info icon,
  styled as secondary text rather than a cobalt link.
- Tapping it reveals the sources, either by expanding in place (preferred in
  Full review, where the page already scrolls) or in a bottom sheet (preferred
  in Quick Play feedback, where the Continue footer must stay reachable).
- The revealed list keeps today's behaviour: publisher and page name, opens in
  the external browser, `Open source: <name>` semantics.
- Collapsed by default every time; no persisted open state.

## Rules that still apply

- Daily Challenge feedback still shows no sources between questions (its total
  timer keeps running). This change only affects Quick Play feedback and Full
  review.
- Image questions: credit and licence stay hidden until an outcome, exactly as
  DESIGN.md section 14 requires. Put image credit in the same disclosure, under
  its own `Image credit` heading, once it is allowed to appear.
- The control needs a 48 logical pixel target, a label that announces the
  count and expanded/collapsed state, and must work at large text sizes.
- Sources stay one tap away. This is about emphasis, not hiding provenance: the
  app's trust comes from citations being easy to reach.

## Also fix while here

In the reference screenshot the third source (`U.S. National Archives - D-Day`)
renders centred while the others are left-aligned; short labels should align
with the rest. (That particular link was also dead; the backend replaced it on
branch `claude/quiz-ww2-links-pack`.)

## Doc follow-up

When implemented, amend DESIGN.md section 14 ("Quick Play feedback may show
explanations and source rows" and "Full review includes image credits and
sources") to say sources and credits sit behind a disclosure.
