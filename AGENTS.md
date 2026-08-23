# AGENTS.md

## Purpose

This repository contains the Flutter mobile app for On This Day.

The app exists to deliver the v0.0.1 daily history loop:

```text
Today -> Featured event -> Learn -> Read more -> Come back tomorrow
```

Every change should support that loop unless the user explicitly asks for a
documented expansion of scope.

## Required Reading

Before making architectural, navigation, state-management, notification, or
cross-cutting UI changes, read the relevant docs:

- `docs/PRODUCT.md` — canonical v0.0.1 product definition, requirements, user
  stories, acceptance criteria, and non-goals.
- `docs/PRODUCT_DECISIONS.md` — product decisions that define the first release
  scope.
- `docs/DESIGN.md` — v0.0.1 visual and UX direction for screens, typography,
  imagery, navigation chrome, and accessibility.
- `docs/ARCHITECTURE.md` — Flutter architecture, boundaries, routes, state,
  API, notification, timezone, and testing guidance.

For UI implementation or visual review, also inspect the static design
references:

- `docs/design/home.png`
- `docs/design/event_details.png`

If the docs and code disagree, call that out before changing behavior.

## Product Scope

v0.0.1 validates one question: will users return regularly to discover today's
historical event?

Keep the first release intentionally small:

- normal launch opens today's home screen;
- the home screen shows today's date;
- exactly one event is visually treated as the featured event;
- additional events are secondary and curated, targeting roughly 6-10 when
  worthwhile content exists;
- selecting any event opens event detail;
- event detail explains what happened and why it matters in concise language;
- every event detail includes at least one source/read-more link;
- notifications are curiosity-driven and deep-link to the referenced event.

Do not add v0.0.1 non-goals unless the user explicitly changes product scope:

- accounts, login, profiles, or personalization;
- arbitrary date browsing, timelines, search, categories, countries, people, or
  complete historical coverage;
- streaks, badges, achievements, leaderboards, social/community features, or
  user-created submissions;
- runtime AI chat, AI-generated event explanations, or visible automated
  significance scoring;
- notification history, notification personalization, multiple daily
  notification types, or user-selectable notification schedules;
- offline mode, video, audio, maps, image galleries, or event-specific
  interactive media.

## Product Decisions To Preserve

- One featured historical event is the hero for each calendar date.
- Additional events are useful only when they support curiosity without making
  the screen feel exhaustive.
- Featured-event selection is editorial for v0.0.1.
- Historical event IDs are stable and must work across home, detail, and
  notifications.
- Imagery is optional; layouts must remain complete when no image exists.
- Sources are part of the core experience and must be clear enough for users to
  understand where links lead.
- Disputed or approximate historical dates use the most widely recognized date,
  with uncertainty explained in content where relevant.
- Normal app launches begin with today, not a previously viewed event.

## Design Direction

For UI, interaction, or copy-layout work, follow `docs/DESIGN.md` where
necessary. Treat `docs/design/home.png` and `docs/design/event_details.png` as
the canonical v0.0.1 visual references for the two primary screens.

The app should feel like a polished consumer history product: editorial,
refined, calm, trustworthy, warm, modern, and readable. The experience should
feel closer to a modern history magazine or curated archive than a generic
Flutter demo, database, classroom tool, encyclopedia, dashboard, or news feed.

Preserve the v0.0.1 baseline:

- centered "On This Day" masthead;
- warm paper full-screen background;
- soft ivory editorial surfaces;
- thin pale stone borders instead of heavy shadows;
- archival cobalt date/year metadata and source links;
- muted copper rules or small accents used sparingly;
- large editorial event titles with readable body copy;
- compact "Also on this day" rows with year, title, and subtle tap affordance;
- native-feeling back navigation and clear external-link affordances.

Avoid introducing bottom tabs, drawers, search/profile/settings actions,
category chips, dense CRUD layouts, parchment/scroll/wax-seal styling, heavy
sepia treatment, excessive rounded cards, decorative event-specific icons, or
generic stock-like imagery.

Historical imagery is optional. When an event has no image, do not add empty
placeholders; use typography, spacing, borders, and accents to keep the layout
complete.

## Architecture

Use feature-oriented organization and keep shared infrastructure lean.

Preferred shape:

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

Responsibilities:

- `core` contains app-wide API setup, configuration, navigation helpers,
  notification setup/token handling, and shared result/error types when useful.
- `features/on_this_day/domain` contains app-facing models and repository
  contracts. Model what the app needs rather than mirroring backend storage.
- `features/on_this_day/data` contains DTOs, JSON parsing, backend mapping,
  repository implementations, and API error translation.
- `features/on_this_day/presentation` contains screens, widgets, and
  presentation state for home and event detail.

Keep UI and data access separate. Widgets should render state and forward user
actions; they should not parse HTTP responses or call HTTP clients directly.

## API And Data

Use repositories as the boundary between presentation/state code and backend
data access.

Expected repository behavior:

- load today's content using the user's timezone;
- load event detail by stable event ID;
- map API DTOs into domain models;
- translate network/API failures into app-level errors;
- hide backend route details from UI code.

Expected backend calls:

```text
GET  /v1/days/today?timezone=Area/Location
GET  /v1/events/{eventId}
POST /v1/devices
DELETE /v1/devices/{token}
```

The app should display the date returned by the backend rather than assuming its
own computed date is the final resolved content date.

Do not put API secrets, Firebase service-account credentials, signing keys, or
environment secrets in the mobile app. Values bundled into the app, including
API base URLs and Firebase client configuration, are not secrets.

## State, Navigation, And Notifications

Start with simple Flutter-native state management. Do not introduce another
state-management framework without an explicit architectural decision.

State should represent loading, loaded, unavailable/empty, error, and retry
paths. Avoid business logic inside widget `build` methods.

Primary routes for v0.0.1:

```text
/today
/events/:eventId
```

Navigation expectations:

- normal launch starts at `/today`;
- selecting the featured event opens its event detail;
- selecting an additional event opens its event detail;
- selecting a source opens the external URL using platform-appropriate browser
  behavior;
- notification taps navigate to `/events/:eventId` whether the app is closed,
  backgrounded, or already running.

Notification responsibilities:

- request permission at an appropriate moment;
- retrieve and refresh FCM tokens;
- register tokens with platform, timezone, and permission status where
  available;
- handle notification tap payloads containing a stable event ID;
- delete or disable backend registration when appropriate.

## Flutter Guidelines

- Follow effective Dart conventions and sound null safety.
- Prefer immutable widgets and models where appropriate.
- Keep widgets reasonably small and focused.
- Prefer straightforward Flutter code over speculative abstractions.
- Avoid adding dependencies without a concrete product or engineering benefit.
- Preserve native iOS and Android behavior where practical.
- Treat accessibility as a requirement.
- Do not suppress analyzer warnings without justification.

## Testing And Verification

For behavior changes, add or update focused tests where practical.

Prioritize coverage for:

- repository mapping from API responses to domain models;
- home state transitions for loading, success, unavailable, and error;
- event detail state transitions;
- route generation and event IDs;
- notification tap handling;
- distinct rendering of featured and additional events.

Use fake repositories for presentation tests. Do not require live backend calls
in mobile tests.

Before finishing changes:

1. Run `dart format` on edited Dart files.
2. Run relevant Flutter tests.
3. Run `flutter analyze`.
4. Review the diff.
5. Summarize what changed and what was intentionally left untouched.

If a verification step cannot run, explain why.

## Branching And Review

Feature work, behavior changes, architecture changes, dependency changes, and
other major updates should happen on a dedicated branch by default.

Use a `codex/` branch prefix unless the user asks for a different branch name.
Keep branch names short and descriptive, for example:

```text
codex/home-featured-event
codex/notification-deeplink
codex/api-client
```

The agent should prepare the branch and changes, then summarize the diff and
verification results. The user will open the PR, review it, and merge when
ready.

Do not merge changes, push branches, or open PRs unless the user explicitly
asks for that action.

Small documentation-only edits may be made on the current branch when the user
asks for them, but keep them focused and easy to review.

## Agent Workflow

Before implementation:

1. Read this file.
2. Read relevant product and architecture docs.
3. Inspect nearby code and existing patterns.
4. For non-trivial work, state a concise implementation plan.
5. Keep the requested acceptance criteria in scope.

During implementation:

- Keep changes focused.
- Explain non-obvious choices in plain language.
- Do not redesign unrelated screens.
- Do not add unrequested features.
- Do not replace established architecture just because another pattern is
  possible.
- Update docs when an architectural or product decision changes.

After implementation:

- Format, test, analyze, and review the diff as appropriate for the change.
- Mention any intentionally deferred v0.0.1 non-goals.
- Call out risks, assumptions, or verification that could not be completed.

## Collaboration

The user is comfortable with backend engineering but may not know Flutter or
Dart. When explaining Flutter choices, connect them to familiar concepts such
as controllers/services, DTO mapping, repository boundaries, routing, and
dependency seams.

Do not make code changes without giving the user a chance to review the plan
first. Documentation-only updates may be made directly when requested, but keep
the diff focused and easy to review.
