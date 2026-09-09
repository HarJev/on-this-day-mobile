# On This Day — Product Decision Log

PD-001 through PD-019 preserve v0.0.1. PD-020 onward specify the approved
Quiz v0.1.0 expansion, which is planned rather than implemented in mobile.

## PD-001 — The product is centered on one featured historical event per day

**Decision**  
For each calendar date, the product will select exactly one historical event as the day's featured event.

**Rationale**  
The product should give the user an obvious place to begin rather than asking them to choose among many historical events. The core experience is intended to answer: “What important thing happened on this day in history?”

**Implications**  
- The home screen must visually distinguish one featured event.
- Other events from the same date are secondary.
- The featured event becomes the basis for the daily notification.  

## PD-002 — v0.0.1 is designed to validate repeat daily usage

**Decision**  
The primary product question for v0.0.1 is whether users will return regularly to discover the day's historical event.

**Rationale**  
The first release should validate the core daily-history habit before investing in broader functionality.

**Implications**  
Features that do not materially support the daily discovery experience are excluded from v0.0.1. 

## PD-003 — The experience should prioritize concise historical understanding

**Decision**  
Historical content will be designed for short sessions rather than long-form study.

**Rationale**  
A user should be able to quickly understand what happened and why it mattered without the app attempting to replace Wikipedia, books, documentaries, or other long-form resources.

**Implications**  
- Event descriptions should generally be one concise paragraph.
- The app provides context and significance but directs users elsewhere for deeper reading.  

## PD-004 — External sources are part of the core event experience

**Decision**  
Every event must provide at least one external source or read-more link.

**Rationale**  
Users should be able to verify the information and continue learning without the application reproducing full source material.

**Implications**  
- Sources are required canonical content for every event.
- Event detail screens must expose source links.
- Source attribution must make the destination understandable.  

## PD-005 — Daily notifications will use curiosity-driven copy

**Decision**  
The daily notification may use wording different from the formal event title and should create curiosity around the featured event.

**Rationale**  
The notification is intended to encourage the user to open the app rather than simply announce the event, while avoiding misleading or clickbait wording.

**Implications**  
- Featured events require notification-specific title and body content.
- Notification copy is a separate content concern from the normal event title and summary.  
fileciteturn0file0L35-L47 fileciteturn0file0L75-L99 fileciteturn0file0L346-L352

## PD-006 — The daily notification deep-links directly to the featured event

**Decision**  
Tapping the daily notification will open the event detail view for the event referenced by that notification.

**Rationale**  
The notification should provide the shortest possible path from curiosity to the historical content that generated it.

**Implications**  
- Notifications must include or reference the destination event ID.
- Deep linking must work whether the application is closed or already running.  

## PD-007 — Normal app launches always begin with today

**Decision**  
Opening the application normally will display the current day's home screen rather than a previously viewed event.

**Rationale**  
The product is fundamentally organized around today's date and today's historical discovery.

**Implications**  
The application must detect calendar-date rollover and replace the previous day's content when appropriate.  

## PD-008 — The home screen includes a curated set of additional events

**Decision**  
In addition to the featured event, the home screen will target approximately 6–10 additional notable events from the same calendar date.

**Rationale**  
Users should have more history to explore when interested, without turning the experience into an overwhelming or exhaustive list.

**Implications**  
- Fewer than 6–10 events are acceptable when stronger events are unavailable.
- Weak events should not be added simply to meet a numerical target.
- The product does not attempt to display every event associated with a date.  

## PD-009 — Featured-event selection is editorial for v0.0.1

**Decision**  
The featured event for each date will be manually/editorially selected rather than chosen by an automated ranking system.

**Rationale**  
The first release does not require the complexity of automated significance scoring.

The principal editorial factors are:
- long-term historical impact
- number of people affected
- recognizability
- overall historical significance

**Implications**  
- Featured selections can be prepared as part of the product's content set.
- Automated ranking or scoring is not required for v0.0.1.
- The same event may remain featured on that date every year.  


## PD-010 — Historical events have stable internal identities

**Decision**  
Every historical event will have a stable event identifier.

**Rationale**  
The same event must be consistently referenced across the home screen, event detail view, and notifications.

**Implications**  
Event ID is required canonical content for every event.  
fileciteturn0file0L273-L279 fileciteturn0file0L330-L344

## PD-011 — Historical imagery is optional

**Decision**  
Events may include historical imagery, but images are not required for an event to exist, appear in the application, or be selected as the featured event.

**Rationale**  
Useful historical events should not be excluded or delay the release simply because suitable licensed imagery is unavailable.

**Implications**  
- The interface must remain visually complete without an image.
- Featured events should use good imagery when it is readily available.
- The content model must support image source, attribution, creator, and licensing metadata where applicable.
- Complete image coverage is not required for v0.0.1.  
fileciteturn0file0L304-L326

## PD-012 — Disputed historical dates use the most widely recognized date

**Decision**  
When an event's exact date is approximate or disputed, the product will associate it with the most widely recognized date.

**Rationale**  
A consistent calendar date is needed for the daily experience while still representing historical uncertainty accurately.

**Implications**  
- The event description must state when the date is approximate or disputed.
- Other commonly cited dates may be mentioned where useful.  


## PD-013 — v0.0.1 does not require user accounts or personalization

**Decision**  
The first release will not include accounts, login, profiles, personalized recommendations, history-interest preferences, or cross-device synchronization.

**Rationale**  
These capabilities are not required to validate the core daily-history experience.

**Implications**  
A first-time user must be able to access today's historical content without registering or logging in.  
fileciteturn0file0L360-L373 fileciteturn0file0L601-L608

## PD-014 — v0.0.1 is centered exclusively on today rather than historical browsing

**Decision**  
The first release will not include global search, arbitrary-date browsing, timelines, or browsing by year, century, category, country, or person.

**Rationale**  
The core experience is specifically focused on discovering history associated with the current calendar date.

**Implications**  
The application does not need navigation structures for broader historical exploration in v0.0.1.  
fileciteturn0file0L399-L412

## PD-015 — Gamification and social features are outside v0.0.1

**Decision**  
The first release will not include gamification systems or social/community functionality.

**Rationale**  
Neither category is required to validate the fundamental daily discovery behavior.

**Implications**  
v0.0.1 excludes features such as:
- streaks, achievements, badges, points, levels, and leaderboards
- comments, followers, likes, social profiles, feeds, and community submissions  


## PD-016 — Runtime AI content generation is not part of v0.0.1

**Decision**  
The product will not generate event explanations or personalized summaries using AI at runtime, and it will not include an AI chat experience.

**Rationale**  
These capabilities are outside the functionality necessary to validate the first release.

**Implications**  
Content may still be prepared using external tooling, but that is considered a content-operations or implementation decision rather than a user-facing v0.0.1 feature.  


## PD-017 — v0.0.1 requires only two primary application screens

**Decision**  
The initial product consists of two primary screens:

1. Home
2. Event Detail

**Rationale**  
These two screens are sufficient to support the complete core experience.

**Implications**  
- Home contains today's date, the featured event, optional imagery, and additional events.
- Event Detail contains the event's date, description/context, optional imagery, and sources.
- No standalone onboarding flow is required unless minimal explanation becomes necessary for notification handling.  


## PD-018 — The v0.0.1 core experience consists of three user flows

**Decision**  
The complete core experience for the first release is represented by:

1. Normal discovery:  
   Open app → Today's page → Featured event → Event detail → Optional external source

2. Additional-event discovery:  
   Open app → Today's page → Additional event → Event detail → Optional external source

3. Daily notification:  
   Receive notification → Tap notification → Event detail → Optional external source

**Rationale**  
These flows cover the intended ways a user discovers, understands, and returns to daily historical content.

**Implications**  
Functionality outside these flows needs a specific justification before being included in v0.0.1.  


## PD-019 — The governing scope rule is “Today → Featured event → Learn → Read more → Come back tomorrow”

**Decision**  
v0.0.1 will use the daily discovery loop as its scope boundary.

**Rationale**  
If removing a feature would still allow the user to discover today's featured event, understand it, explore a few related events, and return through the next day's notification, that feature probably does not belong in the first release.

**Implications**  
This rule should be used when deciding whether proposed functionality belongs in v0.0.1.  

## PD-020 — Quiz is an explicit v0.1.0 expansion

Daily Challenge and Quick Play add a second product area without redefining
v0.0.1. Today remains normal launch; event discovery and notifications remain
compatible. Today/Quiz bottom navigation is approved on root screens only.

## PD-021 — Daily uses the backend's dated assignment

One persisted 20-question assignment exists worldwide per calendar date; five
and ten use its stable prefixes. Timezone resolves the date, not a distinct
question set. Use backend date/identity, retain API presentation order, and keep
each received session immutable. Assignment membership is immutable, but valid
backend editorial corrections may affect content returned to later sessions.

## PD-022 — First completed Daily result is official locally

One official completed result is allowed per backend date across all sizes.
Completing five first makes later ten/twenty practice. Expiry completes;
abandonment does not. This clarifies the backend's "first attempt" wording for
mobile: restarting abandoned attempts is permitted in this casual device-local
experience. Backend attempt tracking and cross-device synchronization remain
excluded.

## PD-023 — Quick Play uses Mixed or one catalog collection

Default to Mixed and five questions. Omit collectionId for Mixed. Use catalog
supported counts; never silently shorten a requested quiz. Refresh stale
collection/count selections after backend rejection.

## PD-024 — Timing depends on mode and continues in the background

Daily always uses the backend total of 120/240/480 seconds for 5/10/20. It runs
through compact feedback and background time. Full explanations/sources wait
until review. Quick Play defaults to 20/20/30/45 seconds by type, can be disabled
locally, and continues timing the current unanswered question in the background.
On expiry it stays in feedback until Continue; feedback has no Quick Play timer.

## PD-025 — Choice taps commit immediately; grading is local

Multiple choice, true/false, and image identification commit on an option tap,
lock input, and immediately reveal correctness and the correct answer. No
Submit answer button. Chronological ordering alone requires Submit order.
Quick Play may include explanations/sources in feedback; all results provide
full review. Preserve backend answers separately from user responses.

## PD-026 — Collections stay flat and grouped

Use topic, historical_period, civilization, and conflict_or_movement for catalog
presentation, without a parent/child taxonomy. Read counts and names from the API.

## PD-027 — Difficulty and speed do not change scoring

One credit per correct question; ordering requires the complete correct order.
Timeouts and image skips are unanswered with zero credit. Difficulty is secondary
metadata. Best results compare only matching count/mode/selection groups; ties
keep the earlier result and do not introduce a speed-based score.

## PD-028 — Content remains curated and provenance is retained

Consume the backend's initial 60-question bank; expansion to 240 is backend
content work. Keep explanations, sources, image attribution and license data.
Image alt text should be neutral. No runtime generation or user-created content.

## PD-029 — Completion freezes and saves immediately

Last committed answer, final skip/timeout, or Daily expiry freezes the result
and starts persistence exactly once, independently of Results navigation. A
pending official result reserves its date in memory after save failure; replays
cannot replace it. Retry that same frozen result idempotently. Process death
before a successful save can lose it; do not imply stronger durability.

## PD-030 — SQLite stores local results

Use sqflite behind a quiz result-store contract for atomic official records,
versioned review snapshots, best results, and timing preference. No database
plugin types in controllers. No standalone history screen or backend storage.
Do not treat unreadable storage as proof that no official result exists.

## PD-031 — Required image failure never causes a scoring penalty

Prepare images before timing with bounded transfer, decode, and memory budgets.
Offer retry/exit when preparation fails; a runtime image failure technically
interrupts play without a scored completion. Never remove or replace questions
to hide failure. Image identification permits Skip question for zero credit,
but this is not equivalent accessibility for blind users. Ordering supports
non-drag controls.

## PD-032 — Unfinished sessions remain in memory only

Background/resume reconciles elapsed time; exit confirmation does not pause it.
Process termination abandons an unfinished session. No restoration or automatic
scored completion of that lost session occurs. Normal launch opens Today.
Completed persisted results survive; no accounts or synchronization are added.
