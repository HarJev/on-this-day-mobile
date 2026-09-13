# On This Day Mobile Architecture

The existing sections describe v0.0.1. The final Quiz v0.1.0 section is approved
implementation guidance, not a claim that quiz code already exists. It explicitly
extends navigation and local storage while preserving the daily-history loop.

## Purpose

The mobile app exists to deliver the v0.0.1 daily history loop:

```text
Today -> Featured event -> Learn -> Read more -> Come back tomorrow
```

The app should stay small, understandable, and easy to change while the product
validates whether users return for a daily historical event.

v0.0.1 has two primary screens:

- Home
- Event Detail

System notification permission UI may appear, but it is not a separate product
screen.

## Technology Choices

- Framework: Flutter
- Language: Dart
- Backend communication: HTTP API client
- Notifications: Firebase Cloud Messaging
- State management: simple Flutter-native state first

Avoid adding dependencies until there is a clear product or engineering benefit.

## Feature Structure

Use feature-oriented organization. Keep shared code small and practical.

Preferred structure:

```text
lib/
  core/
    api/
    config/
    navigation/
    notifications/
  features/
    on_this_day/
      data/
      domain/
      presentation/
```

### `core`

Contains app-wide infrastructure that is not specific to one screen:

- API client setup,
- environment/configuration,
- routing/navigation helpers,
- notification setup and token handling,
- shared error/result types when useful.

Keep `core` lean. Do not turn it into a dumping ground for feature behavior.

### `features/on_this_day/domain`

Contains the app's local product model and repository contracts.

Suggested model concepts:

- `HistoricalEvent`
- `FeaturedEvent`
- `DailyContent`
- `EventSource`
- `EventImage`

The domain layer should describe what the app needs, not mirror every backend
database field.

### `features/on_this_day/data`

Contains implementations that fetch and map backend data:

- API DTOs,
- JSON parsing,
- repository implementations,
- API error mapping.

Widgets should not parse HTTP responses directly.

### `features/on_this_day/presentation`

Contains user-facing UI and presentation state:

- home screen,
- event detail screen,
- widgets for featured and additional events,
- loading, empty, and error states.

Presentation code should depend on repository interfaces rather than concrete
HTTP clients.

## Repositories

Use repositories as the boundary between UI/state code and backend data access.

Suggested contract:

```text
OnThisDayRepository
  getTodayContent(timezone)
  getEvent(eventId)
```

The repository is responsible for:

- calling the API client,
- mapping API DTOs into domain models,
- translating API/network failures into app-level errors,
- hiding backend route details from the UI.

For v0.0.1, avoid adding local persistence unless there is a concrete need.
There is no explicit offline-mode requirement.

## API Client

Use a small API client wrapper instead of calling an HTTP package from widgets
or view models.

Responsibilities:

- store the API base URL from app configuration,
- set common headers,
- encode query parameters,
- decode JSON responses,
- expose typed methods for backend routes,
- normalize transport-level errors.

Expected backend calls:

```text
GET  /v1/days/today?timezone=Area/Location
GET  /v1/events/{eventId}
POST /v1/devices
DELETE /v1/devices/{token}
```

The app should send the user's timezone when requesting today's content and when
registering a notification token. Device registration should also include
notification permission status when available.

Do not put API secrets in the mobile app. Values bundled into the app, including
the API base URL and Firebase client configuration, must not be treated as
secrets.

## State Management

Start with simple Flutter-native state management.

For v0.0.1, likely state owners:

- `HomeController` or equivalent for today's content loading and refresh.
- `EventDetailController` or equivalent for loading a selected event.
- `NotificationService` for FCM token, permission, and notification tap events.

State should represent:

- loading,
- loaded,
- empty or unavailable content,
- error with retry.

Avoid putting business logic directly in widget `build` methods. Widgets should
render state and forward user actions.

Do not introduce a second state-management framework without a specific
architectural decision.

## Navigation

The navigation model should reflect the two-screen product.

Routes:

```text
/today
/events/:eventId
```

Normal launch behavior:

- opening the app normally starts at today's home screen,
- the app should refresh or reload content when the local calendar date changes.

Event selection behavior:

- selecting the featured event opens event detail,
- selecting an additional event opens event detail,
- selecting a source opens the external URL using platform-appropriate browser
  behavior.

Notification launch behavior:

- tapping a daily notification opens `/events/:eventId`,
- this must work when the app is closed, backgrounded, or already running.

Keep navigation explicit and testable. Avoid adding a larger navigation
structure for search, tabs, timelines, profiles, or settings in v0.0.1.

## Notification Handling

Firebase Cloud Messaging is used for daily featured-event notifications.

Mobile responsibilities:

1. Ask for notification permission at an appropriate moment.
2. Retrieve the FCM token.
3. Register the token with the backend.
4. Send platform, timezone, and notification permission status with
   registration when available.
5. Listen for token refresh and reuse `POST /v1/devices` to upsert the new
   token.
6. Handle notification taps and navigate to the included event ID.
7. Disable or delete the backend registration when appropriate.

Expected notification payload data:

```text
eventId=<stable event id>
```

The backend owns notification scheduling and copy. The app owns permission,
device token lifecycle, and deep-link navigation.

Firebase-opened messages and debug local notifications both pass through the
same `NotificationPayloadParser`, `NotificationService` tap stream, and
`NotificationNavigationCoordinator`. Debug builds may expose a local
notification action for simulator testing; it must be absent from release UI.
That path verifies the system banner, payload, route, and event-detail loading,
but it does not prove APNs/FCM remote delivery.

For v0.0.1, do not build:

- user-selectable notification schedules,
- notification categories,
- notification history,
- multiple daily notification types,
- notification personalization.

## Date and Timezone Behavior

The app should determine the user's current timezone and send it to the API.

The backend returns the resolved date and content for that date. The app should
display the returned date rather than independently assuming the response's
calendar day.

The app should refresh today's content when:

- the app launches,
- the user manually retries after an error,
- the app resumes after enough time has passed that the local date may have
  changed.

Special February 29 behavior is not required for v0.0.1.

## Error and Empty States

The app should handle ordinary failure modes without exposing technical details
to users.

Required states:

- loading today's content,
- loading event detail,
- network/API error with retry,
- content unavailable for the resolved date,
- event unavailable or removed.

The product intends to support every release date, so empty content should be
treated as a backend/content issue, not as a normal browsing state.

## Testing Strategy

Prefer tests around behavior that affects the product loop.

Useful test coverage:

- repository mapping from API responses to domain models,
- home state transitions for success, loading, and error,
- event detail state transitions,
- route generation for event IDs,
- notification tap handling routes to the expected event,
- widgets render featured and additional events distinctly.

Use fake repositories for presentation tests. Avoid requiring live backend calls
in mobile tests.

Before merging behavior changes:

- run `dart format`,
- run Flutter tests relevant to the change,
- run `flutter analyze`.

## Explicitly Deferred

The mobile app should not implement these for v0.0.1:

- accounts, login, or profiles,
- onboarding unless notification permission needs minimal explanation,
- arbitrary date browsing,
- global search,
- category browsing,
- timelines,
- favorites or saved events,
- streaks, badges, achievements, or other gamification,
- social/community features,
- user-created event submissions,
- offline mode,
- image galleries,
- audio, video, maps, or interactive history media,
- runtime AI chat or personalized AI summaries.

The v0.0.1 mobile architecture is complete when it can reliably:

```text
load today's content
show one featured event
show curated additional events
open event detail
open external sources
register for notifications
deep-link from notification to event detail
```

## Quiz v0.1.0 Architecture

### Boundaries and composition

Add `lib/features/quiz/domain/`, `data/` (including `dto/` and `local/` when
needed), and `presentation/`. Reuse ApiClient, AppConfig, TimezoneProvider,
SourceLauncher, AppTheme, and AppRouter through constructor injection. Continue
ChangeNotifier/ListenableBuilder; widgets render state and forward actions.
No HTTP JSON, SQLite, or Firebase plugin types enter quiz controllers.

Domain models: QuizCatalog, QuizCollection and availability/group enums;
QuizDefinition with Daily/Quick Play metadata and mode-specific timer policies;
sealed MultipleChoiceQuestion, TrueFalseQuestion, ImageIdentificationQuestion,
and ChronologicalOrderingQuestion; QuizOption, QuizOrderingItem, QuizSource,
and QuizImage. QuizImage retains URI, alt text, source/source URL, attribution,
optional creator, license/license URL. Quiz models do not import event models.

Keep immutable canonical questions and answers separate from QuizAnswer values
(option ID or ordered item IDs), QuestionOutcome, and frozen QuizResult snapshots.
Validate shape/reference invariants at the data boundary and defensively copy
collections. Grading is pure Dart: one credit for a correct question, exact full
order for ordering, no difficulty/speed multiplier.

QuizRepository: getCatalog(), createQuickPlay(questionCount, collectionId?), and
getDaily(timezone, questionCount). QuizResultStore: official lookup, idempotent
completion recording, comparable best-result lookup, and timing preference.
Provide fakes for both; no DI framework or backend grading call.

### API mapping and setup

Use existing GET/POST JSON operations for `/v1/quizzes/catalog`,
`/v1/quizzes/quick-play`, and `/v1/quizzes/daily`. Omit collectionId for Mixed;
encode timezone and questionCount as query values for Daily. Map wire enums
explicitly and quiz source displayName independently from event source name.
Preserve API presentation order; do not shuffle again on mobile.

Validate complete response count, unique IDs, required answer references, four
options/items where applicable, canonical True/False, sources, images, dates,
and timer policy before play. Quick Play requires per-question timeLimitSeconds;
Daily uses timer.durationSeconds and has no per-question time limit. Unknown
additive fields may be ignored, but unknown types or broken shapes fail clearly.

Map insufficient_quiz_questions to unavailable selection/catalog refresh;
quiz_collection_not_found to selection recovery; quiz_unavailable to unavailable
with retry; invalid_timezone to retryable timezone failure. Normalize malformed
content, invalid_quiz_request, network and unexpected errors into feature-level
failures with retained diagnostic causes. Do not expose raw errors or silently
drop questions. Bound quiz requests (initial budget: 20 seconds); ignore stale
responses after retry/disposal. A Future timeout alone does not cancel transport.
Do not change unrelated ApiClient consumers just to add quiz request bounds.

QuizSetupController owns loading, ready, empty/unavailable, retryable failure,
and starting states. Catalog supported counts govern Quick Play choices. New
Daily starts recheck timezone and resolve official status against the response
ISO date, not a locally formatted guess. Starting a session freezes date/content;
a new session after rollover resolves again. Daily still needs 20 published
questions for assignment generation even when a smaller prefix is requested.

### Navigation and ownership

One root navigator serves `/today`, `/quiz`, `/quiz/daily`, `/quiz/quick-play`,
`/quiz/play`, `/quiz/results`, `/quiz/review`, and `/events/:eventId`.
Today/Quiz select one retained root shell; switching tabs does not accumulate
routes. Setup, play, results, review, and Event Detail are pushed above it.
Use typed local route arguments for sessions/results, never URL-encoded answers.
Missing arguments yield a recoverable unavailable route.

Screens own and dispose controllers created from injected dependencies. The play
route owns the session controller; an app-scoped quiz completion coordinator owns
pending saves/date reservations so route disposal cannot lose them. It is created
through ordinary composition, not a new state-management framework.

Preserve the existing notification payload/service/coordinator. Warm notification
taps push Event Detail over the active route; returning reconciles quiz time.
Cold launch explicitly establishes Today underneath notified Event Detail.
Normal launches always select Today. Observe route visibility as well as app
lifecycle; a pushed route does not necessarily background the app.

### Session state and exactly-once completion

State flow: preparing -> ready -> answering -> feedback -> answering ... ->
completed, plus preparation failure and abandonment. Include a fake-driven
widget harness during MQ3 so controllers are exercised through realistic input,
feedback, Continue, timeout, and lifecycle paths before shell integration.

An option tap immediately commits/locks choices. Only ordering has explicit
submission. Before accepting an answer, reconcile its deadline; at or beyond
expiry the timeout wins. Quick Play timeout records unanswered and waits in
feedback. Daily timeout marks all remaining unanswered and completes.

Last committed answer, final skip/timeout, or Daily expiry freezes a result once
and immediately hands it to the completion coordinator for saving. Last-question
feedback can remain visible, but Results navigation is not the save trigger.
Guard double taps, repeated expiry/resume callbacks, and duplicate finish events.
Register the pending official date synchronously before awaiting storage; later
sessions for that date are practice. Retry the same result idempotently. Keep
reservations through navigation and save failure for the process lifetime.

Daily feedback contains correctness/correct answer and Continue only; full
explanations and sources appear in final review. Quick Play feedback can include
them. Source launch failures do not discard session state.

### Timer lifecycle

Use an injected elapsed-time source backed by Stopwatch; periodic UI callbacks
only render remaining duration, never decrement authoritative counters. Daily
runs continuously after ready/start, including feedback, background, route cover,
and exit confirmation. Quick Play runs only for the current answering phase,
including background; feedback has no running timer. Continue starts the next
question's timer. Untimed mode has none.

Capture monotonic elapsed time and UTC wall time at lifecycle transitions. On
resume, account for suspension without double-counting: use the larger
nonnegative elapsed interval when wall time exceeds the monotonic interval.
Backward clock changes never restore time; forward changes may expire a timer.
This is a casual local timer, not tamper-proof timekeeping. Validate Stopwatch
suspension behavior on iOS and Android rather than assuming callbacks run while
backgrounded. Reconcile before answer/Continue and on route return/resume.

Cancel UI tickers/listeners at completion/disposal; late callbacks are inert.
Unfinished sessions are not persisted/restored across process death. A surviving
in-memory session resumes with elapsed time accounted for. Process termination
abandons unfinished work; it does not synthesize an official timeout result.

### Bounded image preparation

Prepare every required image in the returned session before timing. Initial
resource limits: two concurrent downloads; 15 seconds per image; 60 seconds per
preparation batch; 8 MiB maximum encoded bytes per image and 32 MiB per session.
Enforce byte limits while streaming, not after buffering an unlimited response.
Use injectable image preparation infrastructure and cancel/release on exit.

Read dimensions, preserve aspect ratio, and request decoding at a longest edge
of at most 1024 pixels and at most 1,048,576 pixels per image. Cap retained decoded
session images at 32 MiB (approximately four bytes per pixel); fail preparation
before timing if the budget cannot be met. Do not decode full-resolution files
first to resize them later. Retain prepared image handles through play to avoid
timed reloads; release handles/buffers at session disposal. Avoid enlarging the
global Flutter image cache or introducing a caching package.

These are starting engineering budgets to verify against all nine canonical
assets in MQ5. If source bytes exceed them, report the affected image and propose
a verified rendition/budget adjustment; never silently bypass bounds. Failed
loading offers retry/exit without a timer or points penalty. Unexpected required
image loss in play terminates as a technical interruption, not a scored result.
Skip question is a separate deliberate user action, unanswered with zero credit.

MQ5 uses `QuizImagePreparer` behind the existing preparation-attempt/lease
boundary. Unique URLs share transfer/decode budgets; each question retains its
own metadata. The HTTP adapter streams bounded chunks using http 1.6's
AbortableRequest. Cancellation is best-effort: cancel subscriptions, signal
supported request abort, ignore late results, and dispose late decoder handles.
Do not equate cancellation with guaranteed termination of an underlying socket.
Per-image deadlines include decoding; the batch deadline includes queueing.
The adapter requires direct HTTPS 200 responses and static decodable images.

`ImageDescriptor` supplies dimensions before target decoding. The decoder
reserves width * height * 4 bytes and validates actual dimensions. These limits
bound retained encoded data and decoded pixels, not all native codec/GPU scratch
allocations. No global ImageCache entry or disk cache is used.

The session owns original decoded handles; the RawImage widget owns a clone.
RawImage does not dispose its supplied handle, so the widget disposes its clone
only when it is no longer buildable. Advancing drops question mappings that are
no longer needed (shared URLs remain until their last use). Completion preserves
only the final reached image through feedback, even if result delivery fails.
Leaving feedback/Results navigation or disposal releases it. Completion timing
and immediate sink delivery remain unchanged. Missing active handles interrupt
the session before answer/timeout grading; intentional terminal cleanup never
rewrites a frozen result. Image credit is a quiet disclosure. Skip is not an
equivalent nonvisual alternative to visual identification.

See `docs/QUIZ_IMAGE_REVIEW.md` for MQ5's canonical asset budget check.

### SQLite persistence

Use sqflite through QuizResultStore, resolving a compatible version in MQ7.
SQLite transactions and uniqueness protect the official result plus review
snapshot. Recommended logical records: official_daily_result keyed by backend
ISO date; best_quiz_result keyed by mode/date-or-collection/count/timing; and a
small preference record. Version both schema and serialized immutable snapshots.
Keep original question/answer/explanation/source/image metadata so later backend
edits cannot rewrite a recorded result. Store image references, not image blobs.

Atomically insert the official record if absent and update comparable best
results. Never replace the existing official result. A local completion identity
makes retries idempotent; retries of the original official save must not become
new practice records. Keep higher correct count, retaining earlier results on
ties. Retain official snapshots and best records; no all-attempt history screen.

Await successful commit before claiming saved. On failure keep frozen pending
results/reservations in memory and expose retry. Unknown/corrupt storage must not
be interpreted as an empty official history; offer recovery or explicitly
non-official play without overwriting it. A pending result may be lost on process
death before commit. Read-only review uses saved snapshots and can show an image
unavailable state without changing the recorded score.

Open storage lazily for Quiz so Today loading is unaffected. Ordinary tests use
fakes; simulator/device integration tests verify real transactions, migrations,
duplicate completion, and restart behavior. sqflite targets mobile here; do not
add web/Windows/Linux persistence adapters during this scope.

### Verification and scope

Follow MQ1-MQ11 in `../quiz_implementation_plan.md`. Verify mapping, grading,
timing/clock/lifecycle races, persistence, all question interactions, source
launching, dynamic text, semantics, and existing navigation with fakes. Use real
SQLite and local SAM for integration checks. No backend changes, notification
changes, accounts, competitive systems, question-bank expansion, or runtime AI.
