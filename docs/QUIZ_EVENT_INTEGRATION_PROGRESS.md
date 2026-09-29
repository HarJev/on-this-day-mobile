# Quiz And Daily Events: Integration Progress

Updated: 2026-09-28. Implementation, automated verification and owner merge COMPLETED. Native walkthrough remains NOT_STARTED. Active next task: backend C1/C2 October 2-8 content slate.

## Current Checkpoint

- Canonical mobile repository: `../on-this-day-mobile`; merged main at `6cd4be8` (checkpoint `f6f5d7d`).
  The Phase 1 Quiz refresh is merged, including bundled typography, Review
  cards, and collapsed Sources/Image credit disclosures.
- Canonical backend repository: `../on-this-day-backend`; inspection at
  `dc329ad` (checkpoint `f0ace9f`). V4 stores explicit event-question relations. Daily selection
  uses approved links for new assignments and preserves existing assignments.
- The owner reported a successful canonical/database comparison: `inSync:
  true`, 118 events, 24 day entries, 196 question records (195 published and
  one retired). Recheck this report after any later content import.
- Implemented additive `relatedEvents` metadata for all question types in
  Daily/Quick Play, batch-loaded from existing V4 relations. Added optional
  Event Detail `hasRelatedQuizQuestions`; lookup failure suppresses the Quiz
  affordance without hiding readable history.
- Implemented immutable/mobile API metadata, backwards-compatible v1 result
  snapshots, completed Results/Review disclosures and internal story routes.
  Current-day Event Detail now also requires published linked availability.
  No linked titles are rendered during gameplay.
- The backend has candidate event links outside canonical content. Their
  approval/promotion is a separate editorial step; no inference from question
  text or automatic approval is part of this implementation.

## Governing References

Read `AGENTS.md`, `CLAUDE.md`, and the shared `../CLAUDE.md` first.

- `docs/DESIGN.md`, sections 15-16.
- `design/claude-design/REVIEW.md`: written corrections override mockups.
- `design/claude-design/phase-1/README.md` and its Results/Full Review screens.
- `design/claude-design/phase-2/README.md` for Event Detail.
- Owner-supplied exports remain in `design_handoff_quiz_refresh_phase_1/`
  and `design_handoff_today_refresh_phase_2/`; preserve them.
- `../on-this-day-backend/docs/API_CONTRACT.md` and `docs/ARCHITECTURE.md`.
- `docs/PRODUCTION_LAUNCH_WORKPLAN.md`, A2, and shared `../PROPOSED_CHANGES.md`,
  PR-01/PR-02. Those tracker rows cover broader work than this task.

## Ordered Tasks

| Task | Status | Acceptance / next action |
| --- | --- | --- |
| Inspect refreshed main and identify API prerequisite | COMPLETED | Quiz refresh confirmed; relationships are not exposed by quiz DTOs. |
| Backend: expose related-story metadata | COMPLETED | Review an additive contract, implement bounded aggregate loading and mapping for all four question types in Daily/Quick Play, and document/test it. |
| Backend: expose Event Detail quiz availability | COMPLETED | Return whether a published question is explicitly linked; do not change selection or approve content. |
| Mobile: immutable metadata and API mapping | COMPLETED | Validate IDs, titles, and years; preserve stable order; missing metadata from older APIs means no related stories. |
| Mobile: frozen snapshot compatibility | COMPLETED | Save metadata for new results; read legacy results without links; retain existing stored fingerprint and idempotency behavior. |
| Mobile: Review and Results story navigation | COMPLETED | Show quiet, wrapping story links after completion using the refreshed design; push existing Event Detail and return to the same Review/Results. |
| Mobile: Event Detail action eligibility | COMPLETED | Offer the current-day Quiz action only with explicit linked-question availability; describe the destination honestly without promising that an arbitrary story is selected in a given Daily size. |
| Automated verification and visual inspection | COMPLETED | 503 Flutter tests, clean analyzer, 198 Java unit tests, 3 PostgreSQL integration tests; normal-phone and 200% Review captures inspected. |
| Owner merge | COMPLETED | Both checkpoints present in canonical main; backend PR #17 and mobile PR #8. No independent runner review evidence was recorded by this task. |
| Native connected-flow walkthrough | NOT_STARTED | Run matching backend/mobile branches and check live Daily, completed Review, Results, and back navigation. |

## Additive Contract

Quiz-question field on both Daily and Quick Play:

```json
"relatedEvents": [
  {
    "id": "stable-event-id",
    "title": "Canonical historical event title",
    "year": "1958"
  }
]
```

Event Detail field: `hasRelatedQuizQuestions: true|false`, based on
published explicitly related questions. An unlinked question returns an empty
list; an older backend omitting either new field is handled conservatively.

Titles and years come from canonical events. Use one bounded batch lookup,
not a query or network request per question. The metadata does not claim that
every related event belongs to the current Daily date. Confirm exact field
names in the backend contract before writing the mobile parser.

## Mobile Behavior

- Add related-story metadata to each immutable question and its frozen review
  snapshot. Do not fetch event titles while building Results or Review.
- Full Review uses a compact `Related history` disclosure styled like the
  existing sources disclosure, with wrapping year/title rows and a chevron.
  Results may offer one related story for its existing Worth revisiting item;
  keep the detailed list in Review.
- Show no linked event titles, IDs, URLs, summaries, or semantics before an
  answer. This task exposes links after session completion only.
- Use the existing Event Detail route/repository. Back returns to the same
  result/review and scroll context. Event-load failures use the existing detail
  error behavior and cannot invalidate the saved quiz result.
- Older results and unlinked quizzes stay complete without placeholders.
  Do not claim a Daily is connected when metadata or approved links are absent.
- Keep backend grading semantics, timers, local completion classification,
  persisted Daily assignments, image bounds/cache, and refresh components.
- Do not use related titles to synthesize dates, answer annotations, or new
  questions. Do not add a filtered-event quiz endpoint in this task.

## Execution And Handoff

The owner approved implementation and small backend changes. This task was
implemented directly on dedicated `codex/quiz-event-metadata` (backend) and
`codex/quiz-event-integration-plan` (mobile) branches; no `.ai-workflow` runner
or independent Claude review was executed by this task. The owner has now
merged both checkpoints. Do not infer independent review from merge alone.
Preserve the owner-supplied design exports.

Backend support stayed additive: no migration, content approval/import,
selection rewrite, or deployment was needed. The larger content follow-up
belongs to L6/L7/A2 C1-C4 below, not this implementation checkpoint.

## Content Follow-up

The owner approved prioritizing natural event-linked questions for the remaining
runway. Backend `docs/CONNECTED_QUIZ_CONTENT_PLAN.md` C1-C4 is the worker
entry point (L6/L7/A2). No content was approved or imported by this task.

## Evidence And Checkpoints

- Backend checkpoint: `f0ace9f` on `codex/quiz-event-metadata`.
- Mobile checkpoint: `f6f5d7d` on `codex/quiz-event-integration-plan`. Scope includes this note and the L7 content-plan cross-reference.
- `mvn -B test`: **198 passed**. Log:
  `../on-this-day-backend/build/quiz-event-integration/maven-test.log`.
- `mvn -B -Dtest=QuizResponseMapperTest,EventDetailHandlerTest -Dit.test=DateLinkedDailyIT verify -Pintegration`:
  **9 focused unit + 3 integration tests passed; BUILD SUCCESS**. Database was
  disposable Testcontainers Postgres, not the project database. Detailed XML:
  `../on-this-day-backend/target/failsafe-reports/`.
- SpotBugs remains reporting-only: existing findings and DataSource/dynamic
  parameterized-placeholder warnings are present. This is not a clean
  SpotBugs/security gate; broader static-analysis cleanup is not part of A2.
- `flutter test --no-pub --reporter expanded`: **503 passed**. Log:
  `build/quiz-event-integration/flutter-test.log`.
- `flutter analyze --no-pub`: **No issues**. Log:
  `build/quiz-event-integration/flutter-analyze.log`.
- Edited Dart files formatted; both Git diff whitespace checks passed.
- Phone (390x844) and 200%-text Review captures inspected for wrapping/overlap:
  `build/quiz-event-integration/screens/review-1.0x.png` and `review-2.0x.png`.
  These are widget captures with bundled fonts, not native device evidence.
- Regression cases include all four shapes in both modes, old snapshots retaining
  byte-for-byte canonical encoding and SHA-256 receipts, strict malformed-link
  rejection, absent older-API metadata, retired-only availability, optional
  lookup failure preserving history, actual router Review/Results loops,
  pending saves, retained disclosures after Back, and no titles in gameplay.
- Canonical inventory (read-only): **34 published linked questions / 37
  relations**. Recheck after later editorial imports.
- No canonical content, imports, migrations, Daily assignments, deploys,
  Firebase settings, or AWS resources changed. Owner design exports preserved.

## Next Worker

1. Both implementation branches are merged. Retain this note as integration
   evidence; do not silently mark broad PR-01 content coverage done.
2. Run the native connected journey with the same updated API. An older API is
   compatible but intentionally shows no related-story affordances.
3. Backend **C1** is complete for October 2-8; **C2** is awaiting owner slate
   review. Active handoff: `../on-this-day-backend/docs/CONNECTED_QUIZ_CONTENT_PROGRESS.md`. Reuse suitable published
   questions before new ones; no forced hooks or automatic editorial approval.
4. Continue C3/C4 only after slate and content review. Event promotion precedes
   question import when linked events are new. Existing Daily assignments do
   not change after an import; no regeneration as part of this content task.
