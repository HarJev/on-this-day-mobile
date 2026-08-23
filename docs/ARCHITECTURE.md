# On This Day Mobile Architecture

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
