# On This Day — Product Specification v0.0.1

**Status:** Canonical product definition  
**Version:** v0.0.1  
**Product:** On This Day mobile app

## 1. Product Goal

On This Day gives users one compelling reason each day to learn about history.

Every calendar day, the app selects one particularly significant historical event that occurred on that date and presents it as the day's featured event.

The experience should answer:

> "What important thing happened on this day in history?"

The product should make discovering history feel quick, interesting, and repeatable rather than overwhelming.

v0.0.1 exists to validate one core behavior:

> Will users return regularly to discover today's historical event?

Everything in the first release should support that question.

---

## 2. Core Product Principles

### 2.1 One event is the hero

There may be many historical events associated with a date, but the app deliberately selects one featured event.

The user should never need to decide where to begin.

### 2.2 Curiosity before information

Notifications should create curiosity rather than simply announcing the event.

Example:

> "A king died in battle 541 years ago today."

Instead of:

> "Battle of Bosworth Field — August 22, 1485."

The notification should encourage the user to open the app without becoming misleading or clickbait.

### 2.3 Fast to consume

A user should be able to:

- open the app,
- understand today's featured event,
- learn why it matters,

within a short session.

The product is not intended to replace Wikipedia, books, documentaries, or long-form history resources.

### 2.4 History with a way to go deeper

The app provides a concise explanation of the event and links to external sources for users who want more detail.

### 2.5 Small first release

v0.0.1 should contain only what is required to deliver the daily-history experience reliably.

Features that improve the product but do not validate the core concept belong in later versions.

---

## 3. Target Experience

### 3.1 Daily notification

Once per day, the user may receive a notification about the day's featured event.

The notification consists of curiosity-driven copy based on the featured event.

Example:

**Title**

> A king died in battle 541 years ago today

**Supporting text**

> Richard III's defeat at Bosworth changed England forever.

Tapping the notification opens the app directly to that event's detail view.

The notification is intended to be the primary re-engagement mechanism for the first release.

Notifications should be delivered once per day at a consistent time based on the user's local time.

If local-time delivery introduces unnecessary complexity for the first release, a general consistent delivery time may be used initially.

User-configurable notification schedules are not required for v0.0.1.

### 3.2 Opening the app normally

When the user opens the app without using a notification, the home screen displays:

**Today's date**

Example:

> August 22

**Featured event**

One prominent historical event selected for the date.

The featured event should contain enough information to make the user interested in opening it.

At minimum:

- event title
- year
- short summary
- optional primary image when suitable imagery is available

**Additional events**

The product should target approximately **6–10 additional notable events** from the same calendar date.

Fewer events may be shown when there are not enough worthwhile events to maintain a high-quality experience.

The goal is to keep the day's content interesting and varied without making the screen feel overwhelming or padding the list with weak historical events.

These events are secondary to the featured event.

Each should contain at minimum:

- event title
- year

Selecting any event opens its event detail view.

### 3.3 Event detail

The event detail view explains the event in a concise, readable format.

It contains:

- event title
- date/year
- event summary
- explanation or description of the event
- optional event imagery
- source/read-more links

The page should give the user enough context to understand:

- what happened
- who or what was involved
- relevant background
- why the event was historically significant

The event description should generally be one concise paragraph.

It should provide a brief summary of what happened, enough background to understand the event, and an explanation of its significance.

The description should be short enough to maintain the user's interest but substantial enough to create curiosity and provide meaningful context.

### 3.4 Read more

Users who want deeper information can follow one or more external source links.

The application does not attempt to reproduce the full source material.

---

## 4. v0.0.1 Functional Requirements

### FR-001 — Current date

The application must determine the user's current calendar date and display it on the home screen.

The historical events displayed must correspond to that calendar date.

### FR-002 — Daily event collection

For every supported calendar date, the product must be capable of returning:

- exactly one featured event
- zero or more additional events

The target is approximately 6–10 additional events per day, although fewer are permitted when appropriate.

The featured event must also be a valid historical event for that calendar date.

### FR-003 — Featured event

The home screen must visually distinguish one event as the day's featured event.

The featured event must include:

- event ID
- title
- historical date
- year
- short summary

The featured event may also include a primary image when suitable imagery is available.

Selecting the featured event must open its event detail view.

### FR-004 — Additional events

The home screen must display additional notable events for today's calendar date when available.

Each additional event must include:

- event ID
- title
- historical date/year

Selecting an additional event must open that event's detail view.

There is no requirement in v0.0.1 for users to browse the complete historical record for the day.

### FR-005 — Event details

Every selectable event must have a detail view.

The detail view must display:

- title
- date/year
- concise historical description
- at least one source/read-more link

The content must allow a reasonable reader without prior knowledge to understand what happened and why the event matters.

The description should generally consist of one concise paragraph covering the event, relevant background, and historical significance.

### FR-006 — Sources

Each event must support one or more external source URLs.

Users must be able to open a source from the event detail view.

Source attribution must be clear enough that the user understands where the external link leads.

Detailed source-quality standards will be defined when the initial content sources are gathered.

### FR-007 — Daily featured-event notification

The application must support one notification associated with the day's featured event.

Notification content must support:

- title
- body
- destination event ID

Notification copy may differ from the event's normal title and summary.

### FR-008 — Notification deep link

Selecting the daily notification must open the corresponding featured event.

If the application is closed, selecting the notification must launch the application and navigate to that event.

If the application is already running, selecting the notification must navigate to that event.

### FR-009 — Normal app launch

Opening the app normally must take the user to today's home screen rather than an arbitrary previous event.

### FR-010 — Historical event identity

Every historical event must have a stable identifier so the same event can be referenced consistently by:

- the home screen
- the event detail screen
- notifications

### FR-011 — Featured event selection

Featured-event selection for v0.0.1 will be editorial rather than automatically determined.

The primary factors used when selecting the featured event should include:

- long-term historical impact
- number of people affected
- recognizability
- overall historical significance

Events may be loaded into the product's content set and the featured event for each date manually selected.

An automated ranking or scoring system is not required for v0.0.1.

### FR-012 — Historical date uncertainty

Where a historical event has a disputed or approximate date, the product should use the most widely recognized date.

The event description should clearly state when the date is approximate or disputed.

Where useful, other commonly cited dates may also be mentioned in the description.

### FR-013 — Event imagery

The product must support historical events having optional imagery.

Images must not be required for an event to be valid, displayed, or selected as the featured event.

The interface must remain visually complete when an event has no image.

The content model should be capable of supporting:

- zero or more images associated with an event
- one primary image for prominent display
- image source
- image attribution
- image creator where applicable
- image license information
- image license URL where applicable

Complete image coverage is not required for v0.0.1.

High-quality, appropriately licensed imagery should be prioritized for featured events when it is readily available.

Missing imagery must not delay the inclusion of an event or the release of the product.

---

## 5. Content Requirements

For v0.0.1, each historical event requires the following canonical content:

| Field | Required | Purpose |
|---|---|---|
| Event ID | Yes | Stable internal identity |
| Title | Yes | Human-readable event name |
| Historical date | Yes | Date on which the event occurred |
| Year | Yes | Easily display historical year |
| Short summary | Yes | Home-screen preview |
| Description | Yes | Event-detail explanation |
| Significance/context | Yes, either explicitly or within description | Explain why the event matters |
| Sources | Yes | Verification and further reading |
| Images | No | Optional visual context for the event |

A featured event additionally requires:

| Field | Required |
|---|---|
| Notification title | Yes |
| Notification body | Yes |
| Primary image | No |

Where imagery is present, sufficient metadata should be retained to preserve its source, attribution, and licensing information.

The same event may be featured on its calendar date every year in v0.0.1. Automatic rotation of featured events is not required.

---

## 6. Explicit Non-Goals for v0.0.1

The following are not part of the first release, even if they may eventually be useful.

### Accounts and personalization

No:

- user accounts
- login
- profiles
- personalized event recommendations
- history-interest preferences
- synchronization across devices

### Social features

No:

- comments
- followers
- likes
- sharing feed
- social profiles
- community submissions

Native OS sharing is not a requirement for v0.0.1.

### Gamification

No:

- streaks
- achievements
- badges
- points
- levels
- leaderboards

### Search and exploration

No:

- global event search
- browsing arbitrary dates
- historical timeline
- browsing by year
- browsing by century
- category browsing
- country browsing
- person browsing

The first release is centered specifically on today.

### Advanced notification features

No:

- choosing notification categories
- multiple routine notifications per day
- notification personalization
- smart notification timing
- notification history
- user-selectable notification time unless technically unavoidable for basic notification delivery

### Content intelligence

No:

- AI-generated event explanations at runtime
- AI chat about events
- personalized AI summaries
- automated significance scoring visible to users

Content may be prepared using tooling outside the runtime product, but that is an implementation/content-operations decision rather than a v0.0.1 user feature.

### Rich media

No requirement for:

- video
- audio
- maps
- image galleries
- interactive timelines
- animations tied to particular historical events

Complete image coverage is not required for v0.0.1.

Events may include imagery where suitable, but every event must remain usable and visually complete without an image.

### Offline functionality

No explicit offline-mode requirement.

### User-created content

Users cannot:

- create events
- edit events
- suggest corrections from inside the app
- submit sources

### Complete historical coverage

The product does not claim to show every event that happened on a date.

It intentionally presents a curated selection.

---

## 7. User Stories

### US-001 — Discover today's history

**As a user,**  
I want to open the app and immediately see a significant event that happened on today's date,  
**so that** I can quickly learn something interesting from history.

### US-002 — Understand why the event matters

**As a user,**  
I want a concise explanation of the featured event,  
**so that** I understand its historical significance without needing prior knowledge.

### US-003 — Discover more events from today

**As a user,**  
I want to see several additional events from the same date,  
**so that** I can explore more history if the featured event does not satisfy my curiosity.

### US-004 — Explore an event

**As a user,**  
I want to select an event and read more about it,  
**so that** I can understand what happened.

### US-005 — Verify or continue reading

**As a user,**  
I want access to the event's sources,  
**so that** I can verify the information or continue learning elsewhere.

### US-006 — Be reminded of today's event

**As a user who allows notifications,**  
I want to receive an intriguing daily historical notification,  
**so that** I am reminded to discover today's event.

### US-007 — Open the notified event directly

**As a user,**  
I want tapping the notification to take me directly to the event it describes,  
**so that** I do not have to find it manually.

### US-008 — Connect visually with history

**As a user,**  
I want historical imagery to accompany events when suitable imagery exists,  
**so that** the subject feels more engaging and tangible.

---

## 8. Acceptance Criteria

### AC-001 — Home screen date

**Given** the user opens the application normally  
**When** the home screen loads  
**Then** the current calendar date is shown  
**And** the events shown correspond to that date.

### AC-002 — Single featured event

**Given** today's historical content exists  
**When** the home screen loads  
**Then** exactly one event is visually presented as the featured event.

### AC-003 — Featured event preview

**Given** the featured event is displayed  
**Then** the user can see at least:

- its title
- its historical year
- a short description or summary.

If a primary image is available for that event, the product may also display it.

### AC-004 — Additional events

**Given** additional events exist for today's date  
**When** the home screen loads  
**Then** they are displayed separately from the featured event  
**And** none is visually confused with the primary featured event.

The product should target approximately 6–10 additional events while allowing fewer when appropriate.

### AC-005 — Open event

**Given** an event is shown on the home screen  
**When** the user selects it  
**Then** the corresponding event detail view opens.

### AC-006 — Event understanding

**Given** the user opens an event  
**Then** the event detail view provides enough information to identify:

- what happened
- when it happened
- relevant background
- why it is historically relevant.

### AC-007 — Source access

**Given** the user is viewing an event  
**Then** at least one source/read-more option is available  
**And** selecting it opens the intended external resource.

### AC-008 — Notification content

**Given** notifications are enabled  
**When** the daily notification is delivered  
**Then** it refers to today's featured event  
**And** its copy may use curiosity-driven wording rather than the formal event title.

### AC-009 — Notification navigation

**Given** the user receives a daily notification  
**When** the user selects it  
**Then** the application opens  
**And** the event detail view for the event referenced by the notification is displayed.

### AC-010 — Date rollover

**Given** the calendar date changes  
**When** the app is subsequently opened or refreshed  
**Then** the application presents the new date's featured event and additional events rather than continuing to present the previous day's content.

### AC-011 — No account dependency

**Given** a first-time user installs and opens the app  
**Then** they can access today's events without:

- registering
- logging in
- creating a profile.

### AC-012 — Optional imagery

**Given** an event has a suitable image  
**When** the event is displayed  
**Then** the application may show the image in the featured event or event detail experience.

**Given** an event has no suitable image  
**When** the event is displayed  
**Then** the layout remains visually complete  
**And** the event remains fully usable  
**And** it may still be selected as the featured event.

### AC-013 — Disputed historical dates

**Given** an event's exact historical date is approximate or disputed  
**When** that event is displayed in detail  
**Then** the product uses the most widely recognized date  
**And** clearly identifies the uncertainty  
**And**, where relevant, mentions other commonly cited dates.

---

## 9. Minimum Screen Set

v0.0.1 requires only two primary application screens.

### Home

Contains:

- today's date
- featured event
- optional featured-event image
- additional events

### Event Detail

Contains:

- event title
- historical date/year
- event description/context
- optional event imagery
- source/read-more links

System-level notification permission UI is not considered a separate product screen.

No onboarding flow is required unless the operating system or notification implementation makes a minimal explanation necessary.

---

## 10. Core User Flows

### Flow A — Normal discovery

**Open app → Today's page → Featured event → Event detail → Optional external source**

### Flow B — Browse another event

**Open app → Today's page → Additional event → Event detail → Optional external source**

### Flow C — Daily notification

**Receive notification → Tap notification → Event detail → Optional external source**

These three flows represent the complete core experience required for v0.0.1.

---

## 11. Definition of a Successful v0.0.1

v0.0.1 should be considered product-complete when a user can reliably:

1. open the app on any supported day,
2. see today's date,
3. immediately identify one featured historical event,
4. see approximately 6–10 other historical events from that date when sufficient worthwhile events are available,
5. open any displayed event,
6. understand what happened, its relevant background, and why it matters,
7. see historical imagery where suitable imagery is available without the experience depending on it,
8. open external sources,
9. receive a curiosity-driven notification for the featured event,
10. tap that notification and arrive at the correct event.

Featured events for v0.0.1 may be manually selected using long-term historical impact, number of people affected, recognizability, and overall historical significance as the principal editorial criteria.

Detailed source-quality standards will be determined as the initial historical content and sources are gathered.

Special February 29 behavior is not required for v0.0.1.

Future versions that allow users to browse or select arbitrary dates may define specific February 29 behavior. Possible future behavior on non-leap years may include surfacing February 29 content on February 28 or March 1, including the possibility of an additional notification.

Anything beyond these capabilities requires a specific reason to be included in v0.0.1.

---

## 12. Scope Boundary

A useful rule for v0.0.1:

> If removing a feature would still allow a user to discover today's featured historical event, understand it, explore a few related events, and return through tomorrow's notification, that feature probably does not belong in v0.0.1.

The first release is therefore deliberately:

> **Today → Featured event → Learn → Read more → Come back tomorrow.**

That is the product.