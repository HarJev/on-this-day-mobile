Updated docs/DESIGN.md to allow event descriptions to be one substantial paragraph or two short paragraphs, matching the approved detail screenshot while still avoiding long article-style content. No app code changes made. I did not run Flutter verification because this was documentation-only.

**Revised V0.0.1 Plan**

**Task 1: App Foundation And Theme**

- Goal: Establish app shell, theme constants, and visual language.
- Satisfies: design palette/type direction, PD-017.
- Files: `lib/main.dart`, `lib/core/config/`.
- Acceptance: app boots; warm paper/ivory/cobalt/copper colors available; no product feature yet.
- Depends: none.
- Out of scope: routing, content, backend, notifications.

**Task 2: Domain Models And Repository Contract**

- Goal: Define app-facing models and repository interface.
- Satisfies: FR-002, FR-003, FR-005, FR-006, FR-010, FR-013; PD-004, PD-010, PD-011.
- Files: `features/on_this_day/domain/`.
- Acceptance: models include backend-resolved home display date, stable event IDs, featured notification title/body, source display name plus URL, optional image metadata including attribution/source/creator/license/license URL, and approximate/disputed-date support through content text or metadata.
- Depends: Task 1.
- Out of scope: HTTP DTOs, Firebase, persistence.

**Task 3: Fake Local Repository**

- Goal: Let UI work fully without backend integration.
- Satisfies: FR-002 through FR-006 with local data.
- Files: `features/on_this_day/data/`.
- Acceptance: returns one featured event, curated additional events, event details, sources, stable IDs, optional/no-image cases.
- Depends: Task 2.
- Out of scope: live API, content completeness.

**Task 4: Navigation**

- Goal: Add `/today` and `/events/:eventId`.
- Satisfies: FR-003, FR-004, FR-008, FR-009; PD-006, PD-007, PD-018.
- Files: `core/navigation/`, `main.dart`.
- Acceptance: normal launch starts at `/today`; event ID route opens detail; invalid route/event has graceful unavailable handling.
- Depends: Tasks 2-3.
- Out of scope: notification platform integration.

**Task 5: Home Controller And States**

- Goal: Load today’s fake content through repository.
- Satisfies: FR-001, FR-002; architecture state guidance.
- Files: `presentation/home_controller.dart`.
- Acceptance: exposes loading, loaded, unavailable/empty content, retryable error; tests cover state transitions.
- Depends: Tasks 2-3.
- Out of scope: backend timezone/date rollover.

**Task 6: Home Screen UI**

- Goal: Render today, featured event, and additional events.
- Satisfies: FR-001, FR-003, FR-004, FR-013; PD-001, PD-008, PD-011.
- Files: `home_screen.dart`, featured/additional widgets.
- Acceptance: matches `docs/design/home.png` direction; renders loading, unavailable/empty, retryable error; no-image layout works; event taps navigate.
- Depends: Tasks 4-5.
- Out of scope: search, filters, date browsing.

**Task 7: Event Detail UI And Source Opening**

- Goal: Render event detail and make “Read more” actually open platform links.
- Satisfies: FR-005, FR-006, FR-012, FR-013; PD-003, PD-004, PD-012.
- Files: detail controller/screen/widgets, source launcher service.
- Acceptance: renders loading, loaded, retryable error, event unavailable/removed; source links open via platform behavior; tests use fake launcher.
- Depends: Tasks 2-4.
- Out of scope: sharing, bookmarks, in-app browser.
- Dependency note: `url_launcher` is justified here.

**Task 8: Backend Repository And Timezone**

- Goal: Wire real API behind the existing repository contract.
- Satisfies: FR-001 through FR-006, FR-010.
- Files: `core/api/`, `core/config/`, `data/` DTOs/repository.
- Acceptance: determines user timezone, calls `GET /v1/days/today?timezone=Area/Location`, displays backend-returned date, maps DTOs, translates errors, tests mapping/errors.
- Depends: Tasks 2-7.
- Out of scope: notifications, offline cache.
- Ambiguity: IANA timezone may require a dependency or platform approach.

**Task 9: App Resume / Today Refresh**

- Goal: Keep normal launch centered on today.
- Satisfies: FR-001, FR-009; PD-007.
- Files: home controller/app lifecycle hook.
- Acceptance: loads on launch, retries manually, refreshes after likely date rollover on resume.
- Depends: Task 8.
- Out of scope: arbitrary date browsing, Feb 29 special behavior.

**Task 10: Notification Permission And Firebase Setup**

- Goal: Add minimal FCM initialization and permission request path.
- Satisfies: FR-007; PD-005.
- Files: `core/notifications/`, platform Firebase config.
- Acceptance: app initializes Firebase; permission can be requested at agreed moment; no schedule settings.
- Depends: Task 8.
- Out of scope: token backend registration, tap routing.
- Dependency note: `firebase_core` and `firebase_messaging` become justified here.

**Task 11: Device Registration And Token Refresh**

- Goal: Register/update notification tokens with backend.
- Satisfies: architecture notification responsibilities.
- Files: notification service, API client device endpoints.
- Acceptance: posts token with platform, timezone, permission status where available; handles token refresh; supports disable/delete path where appropriate.
- Depends: Task 10.
- Out of scope: notification history, personalization.

**Task 12: Notification Tap Routing**

- Goal: Route notification payloads to event detail.
- Satisfies: FR-008; PD-006.
- Files: notification routing adapter, navigation tests.
- Acceptance: `eventId` payload opens `/events/:eventId` from cold/background/running states where testable; back navigation naturally returns toward today.
- Depends: Tasks 4, 10.
- Out of scope: multiple notification types.

**Task 13: Release Hardening And Visual Review**

- Goal: Validate the full v0.0.1 loop.
- Satisfies: testing/accessibility/design guidance.
- Files: focused tests and UI polish only.
- Acceptance: `dart format`, `flutter analyze`, `flutter test`; compare against `docs/design/home.png` and `docs/design/event_details.png`; check dynamic text and small screens; verify loading/error/no-image states.
- Depends: all prior tasks.
- Out of scope: new features beyond v0.0.1.