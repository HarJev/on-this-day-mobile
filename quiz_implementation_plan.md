# Mobile Quiz v0.1.0 Implementation Plan

Status: approved documentation plan; Flutter implementation has not started.
This is Mobile Quiz Q9. MQ1-MQ11 below are subsequent implementation tasks, not
backend Q1-Q9. Backend reference: `16c92b5`, initial 60-question bank.

## Governing decisions

- Today/Quiz root navigation, one root navigator, Today normal launch, existing
  event notification deep links. Preserve the v0.0.1 daily-history experience.
- Choice, true/false, and image answers commit on tap with immediate locked
  feedback. Only ordering uses Submit order. No Submit answer button.
- Daily offers 5/10/20 with 120/240/480 seconds and stable backend prefixes. One
  official completed result per backend date across all counts; expiry counts,
  abandonment does not. Restarting abandoned attempts is allowed locally.
- Daily time includes feedback/background. Its feedback is compact; full
  explanations/sources are in post-quiz review. Quick Play time includes current
  question background time but stops in feedback, waiting for Continue.
- Freeze and save at completion, not Results navigation. Pending official
  results reserve their date in memory through failures and route changes.
- Prepare required images before timing with Architecture's explicit transfer,
  decode, concurrency, and memory bounds. Image failure never costs points.
- Image Skip question is unanswered/zero credit, not equivalent accessibility
  for blind users. Ordering has non-drag controls.
- Use feature-local models/repositories, ChangeNotifier, immutable questions,
  separate answers, injected clocks, and SQLite for local results.

Canonical details are in `docs/PRODUCT.md` section 13, PD-020 through PD-032 in
`docs/PRODUCT_DECISIONS.md`, `docs/DESIGN.md` section 14, and the Quiz section of
`docs/ARCHITECTURE.md`. Earlier v0.0.1 exclusions do not prohibit this explicit
versioned expansion. Backend API shapes remain authoritative for transport.

## Delivery rules

Each task remains independently reviewable and leaves the application runnable.
Use fakes and a widget test harness early; do not wait for production routing to
test realistic gameplay. Create directories only when real files need them.
Preserve the existing dirty mobile worktree; do not bundle unrelated work into
quiz changes. Q9 changes documentation only, with no dependency/code edits,
commit, or push. Future tasks require their own implementation authorization.

For meaningful Dart changes run `dart format lib test`, `flutter test`, and
`flutter analyze`, plus targeted integration checks where specified. Review each
diff. Tests use fake repositories/launchers/clocks and no live backend by default.

## MQ1: Domain, Answers, Grading, And Contracts

Goal: define the app-facing quiz boundary independently of plugins and widgets.

Files/components: `lib/features/quiz/domain/` models, repository/result-store
contracts, typed failures, pure grading functions; matching domain tests.

Acceptance:
- Model catalog groups/availability, Daily/Quick Play definitions and timer
  policies, all four sealed question shapes, sources and complete image metadata.
- Use Uri URLs, defensive immutable lists, valid answer references and counts.
- Keep user option/order answers separate from canonical correct-answer data.
- Model correct/incorrect/timed-out/unanswered outcomes and frozen result data.
- Grade choices by ID and ordering by exact sequence; no partial/speed/difficulty
  credit. Test malformed shapes, duplicate IDs, mutations, and all outcomes.
- Expose QuizRepository and QuizResultStore without HTTP/SQLite types.

Dependencies: approved Q9 documentation. Excludes DTO parsing, plugins, UI,
storage implementation, timer execution, and backend changes.

## MQ2: API DTOs And Backend Repository

Goal: consume the three existing quiz endpoints through ApiClient.

Files/components: `features/quiz/data/backend_quiz_repository.dart`, `data/dto/`,
mapping/request tests and feature-level error translation.

Acceptance:
- Map catalog, Quick Play, and Daily shapes including all four types, source
  displayName, image provenance, backend date, and mode-specific timer metadata.
- Preserve presentation order; omit collectionId for Mixed; encode timezone.
- Validate full quizzes before use; never discard malformed questions or invent
  Daily per-question limits. Keep unknown enum/type errors explicit.
- Test every documented error, malformed JSON/content, bounded request waiting,
  exact returned count, and fake HTTP request construction.

Dependencies: MQ1. Excludes session UI, new API endpoints, and broad ApiClient
refactoring; any request-bound support must preserve existing callers.

## MQ3: Session Controller And Early Widget Harness

Goal: prove realistic session transitions and timing before navigation wiring.

Files/components: `presentation/quiz_session_controller.dart`, state/elapsed-time
abstractions, test fixtures and `test/features/quiz/` fake-driven widget harness.

Acceptance:
- Exercise preparing/ready/answering/feedback/completed/abandoned through widget
  taps and fake clock advances, not just direct controller method assertions.
- Choice taps commit immediately; ordering submits explicitly; inputs lock.
- Daily continues during compact feedback; Quick Play stops until Continue.
- Reconcile background/route visibility and clock changes without restoring time
  or timing unseen questions. At deadline timeout wins over an arriving answer.
- Freeze completion once and immediately call an injectable completion sink.
  Test last-answer/expiry races, double taps, disposal, and stale callbacks.

Dependencies: MQ1; MQ2 is not needed for the fake harness. Excludes SQLite and
root navigation; the harness is test support, not a shipped developer screen.

## MQ4: Choice And True/False Gameplay

Goal: render usable basic play and mode-specific feedback with fake sessions.

Files/components: quiz play view, option widgets, feedback widgets, source rows
under `presentation/`; extend MQ3 widget harness.

Acceptance:
- Tapping an option immediately locks and reveals correctness/correct answer;
  no Submit answer control exists. True/False keeps canonical order.
- Daily shows compact feedback and reachable Continue without full sources or
  explanation. Quick Play supports explanation and external source opening.
- Test source failure, semantics, large text, score isolation, and Continue.

Dependencies: MQ3. Excludes image/ordering widgets, persistence and root wiring.

## MQ5: Image Questions And Resource Preparation

Goal: render required historical images without timing or memory penalties.

Files/components: image question widget, injectable image-preparation adapter,
preparing/retry states, fake image tests and device resource checks.

Acceptance:
- Prepare all session images before Start with Architecture's budgets: two
  downloads, 15 seconds/image, 60 seconds/batch, 8 MiB encoded/image and 32 MiB
  encoded/session, 1024-pixel longest decode edge and 32 MiB decoded/session.
- Enforce byte limits during transfer and decode to target dimensions directly.
  Verify all nine canonical images; report needed adjustments rather than
  bypass bounds. Release retained resources on exit/disposal.
- Retry/exit failure has no points penalty; unexpected in-play image loss is a
  technical interruption, never an automatic wrong answer.
- Test neutral semantics, provenance, aspect ratio, immediate option taps, and
  deliberate Skip question as unanswered/zero credit, including final skip.

Dependencies: MQ4. Excludes image galleries, persistent image caching and backend
asset changes. Document the visual-identification accessibility limitation.

## MQ6: Chronological Ordering

Goal: make all four-item ordering questions operable by touch and assistive input.

Files/components: ordering widget and feedback view; harness/widget tests.

Acceptance:
- Preserve initial API order; store rearrangements separately from answers.
- Drag and labeled up/down actions produce the same valid four-item permutation.
- Submit order commits once; timeout never submits an uncommitted draft.
- Show exact correct order after submission with readable dynamic-text layout.

Dependencies: MQ4. Excludes partial credit, changing server order, and new plugins.

## MQ7: SQLite Results And Completion Coordination

Goal: preserve official and comparable best results through restart and failures.

Files/components: `data/local/` sqflite store/schema/snapshot serialization,
quiz completion coordinator, fake-store tests and device SQLite integration tests.

Acceptance:
- Add compatible sqflite through pub resolution; no ORM/state framework.
- Atomically save official date and full review snapshot with idempotent retries;
  enforce one official date across all sizes and retain the original result.
- Reserve a pending official date before async writing; later sessions remain
  practice through write failures. Coordinator outlives play route disposal.
- Store best results by comparable keys and timing preference, with earlier
  result retained on ties. Do not add speed scoring.
- Test failed write/retry, repeated completion, two sizes on one date, restart,
  migrations, and unreadable storage without overwriting history.
- Keep storage startup independent of Today; persist no unfinished sessions.

Dependencies: MQ1 and MQ3. Excludes all-attempt history UI, synchronization,
backend attempts, desktop persistence adapters, and image blobs.

## MQ8: Results And Full Review

Goal: complete the learning loop and connect frozen completion to persistence.

Files/components: result/review screens, completion integration, source/image
credit views, fake-store widget tests.

Acceptance:
- Save begins on completion even if the user never opens Results.
- Show correct/total, percentage, answered/correct/unanswered, official/practice,
  pending-save/retry status; block replacement of a pending official result.
- Review all questions, correct answers, submitted answers, explanations,
  sources and provenance, including unseen/skipped/timed-out questions.
- Pending result survives navigating away while the app remains alive; review
  does not refetch or rewrite the frozen question/answer snapshot.

Dependencies: MQ3-MQ7. Excludes history browser, share/rewards, and backend scoring.

## MQ9: Quiz Hub And Mode Setup

Goal: configure complete sessions using catalog availability and local history.

Files/components: quiz hub, Daily/Quick Play setup screens/controllers, repository
and result-store integration; widget tests.

Acceptance:
- Render both modes; support 5/10/20, Mixed/grouped collection selection and
  Quick Play timing switch. Defaults are five, Mixed, and timing enabled.
- Respect supported counts; invalidated count requires a valid selection.
- Recheck Daily timezone and response date; classify official/practice using
  saved and pending records, across counts. Abandonment permits a later restart.
- Cover loading, empty, unavailable, stale selection, malformed response, retry,
  duplicate Start and image preparation before timing. Date rollover does not
  rewrite active sessions.

Dependencies: MQ2 and MQ5-MQ8. Excludes search, category hierarchy, notifications
and arbitrary dated challenge requests.

## MQ10: Root Shell, Routing, And App Composition

Goal: expose the completed quiz area while preserving existing discovery flows.

Files/components: `core/navigation/`, `main.dart`, minimal Home composition,
constructor wiring and route/notification regression tests.

Acceptance:
- One retained Today/Quiz root shell and one root navigator; Today normal launch.
- Setup/play/results/review use validated local arguments above the roots.
- Notification opens Event Detail in cold/warm states; cold stack includes Today.
  Returning to an existing quiz reconciles time without discarding it.
- Missing route arguments are recoverable. Disposed play controllers release
  resources while pending result persistence remains owned at app scope.
- Existing Home/Event Detail loading, source opening, debug notification seam,
  and fake-repository tests remain valid.

Dependencies: MQ9. Excludes notification payload/platform changes and routing
frameworks. Respect existing worktree changes during implementation.

## MQ11: Integrated Verification And Visual Review

Goal: verify complete mobile behavior against fakes, native storage, and local SAM.

Files/components: focused integration tests, visual/accessibility fixes, and
DEVELOPMENT.md local commands updated when implementation exists.

Acceptance:
- Run format, tests, analyze; device SQLite migration/restart tests; local SAM
  catalog, both modes, all types and supported counts with imported Q7 content.
- Verify stable Daily prefixes, total expiration, Quick Play background timeout
  waiting for Continue, untimed completion, clock changes, and exactly-once save.
- Verify pending official failure protection, last-answer save before Results,
  skipped/unseen review, technical image interruption, and deliberate abandonment.
- Exercise iOS/Android lifecycle and screen readers, non-drag ordering, large
  text, small screens, image budgets and release absence of debug actions.
- Compare Today/Event Detail with canonical references and Quiz with approved
  editorial direction. Confirm no notification navigation regression.

Dependencies: MQ10. Excludes cloud deployment, backend work, Q8 bank expansion,
accounts, leaderboards, achievements, synchronization and runtime AI.
