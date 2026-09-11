# On This Day — Design Direction v0.0.1

Sections 1-13 retain the canonical v0.0.1 direction. Section 14 defines the
approved Quiz v0.1.0 extension; its UI is not yet implemented. Earlier exclusions
of quizzes, tabs, and categories are scoped to v0.0.1.

**Status:** Design direction  
**Version:** v0.0.1  
**Product:** On This Day mobile app

## 1. Purpose

This document defines the visual and UX direction for the v0.0.1 mobile
application.

The design must support the product's daily history loop:

```text
Today -> Featured event -> Learn -> Read more -> Come back tomorrow
```

v0.0.1 has only two primary screens:

- Home
- Event Detail

The design must not introduce product features outside the v0.0.1 scope.

---

## 2. Design Goal

On This Day should feel like a polished consumer history product, not a generic
Flutter CRUD application.

The experience should answer:

> What important thing happened on this day in history?

The user should immediately understand that one event has been deliberately
selected as today's featured historical event. Additional events are available,
but they are secondary to the daily feature.

The design should make the app feel like a small daily ritual: focused,
readable, trustworthy, and worth returning to tomorrow.

---

## 3. Visual Personality

The visual personality is:

- editorial
- refined
- calm
- intelligent
- trustworthy
- warm
- premium
- lightly historical
- modern and crisp

The product should feel closer to a modern history magazine, museum daily note,
or curated archive than to a database, classroom tool, encyclopedia, or news
feed.

Avoid:

- generic Material Design demo styling
- dense CRUD-style screens
- dashboard-like layouts
- loud red-and-white news styling
- parchment effects
- scrolls, wax seals, or medieval ornamentation
- heavy sepia treatment
- excessive rounded cards
- timelines, search, filters, tabs, or category-driven chrome

The design should communicate:

> Here is the one thing worth knowing today.

---

## 4. Color System

Use an **Ink, Cobalt, Warm Paper** palette.

| Role | Color | Hex |
| --- | --- | --- |
| App background | Warm paper | `#F7F3EA` |
| Primary surface | Soft ivory | `#FFFDF7` |
| Primary text | Deep ink | `#171A1F` |
| Secondary text | Muted gray | `#62656A` |
| Primary accent | Archival cobalt | `#2F5F8F` |
| Secondary accent | Muted copper | `#A66A3F` |
| Divider / border | Pale stone | `#D8D1C6` |
| Subtle fill | Soft warm gray | `#EBE3D6` |

### 4.1 Usage

- Use warm paper for the app background.
- Use soft ivory for article-like feature and detail surfaces.
- Use deep ink for primary reading text and major titles.
- Use muted gray for secondary labels, metadata, and supporting text.
- Use archival cobalt for dates, years, source links, and subtle navigation
  emphasis.
- Use muted copper sparingly for rules, metadata separators, and small
  editorial accents.
- Use pale stone for dividers and borders.

Avoid large blocks of red, bright primary colors, or a palette that feels fully
beige, brown, or sepia.

---

## 5. Typography

Typography is the primary design system.

Use an editorial type pairing:

- **Display / titles:** elegant serif or editorial display face.
- **Body / UI:** clean modern sans-serif with strong mobile readability.

If the first implementation uses system fonts, preserve this relationship
through size, weight, line height, and hierarchy.

### 5.1 Hierarchy

1. Featured event title: largest, editorial, and memorable.
2. Today's date: prominent but calm.
3. Year/date metadata: small, distinctive, and often cobalt.
4. Summary and description: readable with generous line height.
5. Secondary event titles: compact and scannable.
6. Source links: clear but visually secondary.

Text must never overlap, feel cramped, or truncate awkwardly. The design should
prioritize comfortable reading on small mobile screens.

---

## 6. Information Hierarchy

The app has one primary answer per day.

Home hierarchy:

1. App identity and today's date.
2. Featured event image when available.
3. Featured event year/date.
4. Featured event title.
5. Featured event short summary.
6. Additional events from the same date.

Event detail hierarchy:

1. Back navigation.
2. Event date/year.
3. Event title.
4. Optional image.
5. Concise historical description.
6. Read-more source links.

The featured event must never feel like merely the first item in a list. It is
the day's editorial selection.

---

## 7. Home Screen

The Home screen displays today's date, the featured event, and a curated set of
additional notable events from the same calendar date.

Required content:

- App name: "On This Day"
- Today's date, for example "Aug 22" or "August 22"
- Featured event year
- Featured event title
- Featured event short summary
- Optional featured event image
- Additional events section
- Additional event rows with year and title

### 7.1 App Bar

Use a quiet top app bar:

- centered app name
- today's date on the trailing side
- no bottom navigation
- no search icon
- no profile icon
- no settings icon

The app name should feel like a masthead rather than utility chrome.

### 7.2 Featured Event

The featured event uses a framed editorial surface on the warm paper
background.

Preferred treatment:

- soft ivory surface
- thin pale stone border
- generous internal padding
- featured image near the top when available
- large serif title
- cobalt year
- small uppercase descriptor when useful, such as place or event shorthand
- thin copper rule separating metadata from title
- concise summary below title

The entire featured event surface should be a clear tap target.

The surface may be rectangular with only subtle rounding, or square-cornered if
the implementation feels more editorial. Avoid heavy card shadows and overly
rounded consumer-card styling.

### 7.3 Featured Image

Historical imagery is optional.

When available:

- use meaningful event-specific imagery
- avoid generic stock-like imagery
- frame or crop the image with editorial restraint
- preserve readability and visual calm
- avoid excessive dark overlays, blur, or dramatic effects

When unavailable:

- do not show an empty placeholder
- rely on typography, spacing, border, and accent rules to create the feature
  treatment

### 7.4 Additional Events

The additional events section should be titled:

- "Also on this day"

Each row should include:

- year
- event title
- subtle chevron or tap affordance

Rows should be compact, elegant, and scannable. They should use dividers rather
than heavy cards. The year should act as a visual anchor, preferably in archival
cobalt.

Additional events are intentionally secondary. Do not add summaries, images,
filters, category chips, or competing feature cards.

---

## 8. Event Detail Screen

The Event Detail screen explains one selected event in a concise, readable
format.

Required content:

- Back navigation
- Event date/year
- Event title
- Optional event image
- Concise historical description
- Read-more source links

### 8.1 Header and Navigation

Use native-feeling back navigation at the top left.

The app name may remain centered in the top bar as a masthead. Do not introduce
additional actions such as share, bookmark, or settings.

### 8.2 Main Article Surface

Use the same editorial surface language as the Home featured event:

- warm paper app background
- soft ivory content panel
- thin pale stone border
- generous padding
- cobalt date metadata
- thin copper rule
- large serif title
- optional historical image
- readable body copy

The detail view should feel like a short editorial note, not a long article.

### 8.3 Description

The description should be concise and may be one substantial paragraph or two
short paragraphs, similar in length to the approved Event Detail reference
screen. It should cover:

- what happened
- who or what was involved
- relevant background
- why it mattered historically

The UI may visually wrap the copy over multiple lines, but the content should
remain quick to read. Avoid turning the detail page into a long article,
multi-section explainer, or exhaustive encyclopedia entry.

### 8.4 Sources

The source section should use the label:

- "Read more"

Each source row should include:

- source name
- external-link affordance

Sources should be trustworthy and easy to find, but visually secondary to the
event explanation. The external-link icon should be visible enough to signal
that the link leaves the app.

---

## 9. Navigation Behavior

The navigation model is intentionally small.

Routes:

```text
/today
/events/:eventId
```

Supported flows:

1. Normal launch: app opens to today's Home screen.
2. Featured event: Home -> Event Detail -> Home.
3. Additional event: Home -> Event Detail -> Home.
4. Notification: daily notification opens directly to Event Detail.
5. Source link: Event Detail opens the external source using platform behavior.

Do not add:

- bottom tabs
- global navigation drawers
- search destinations
- arbitrary date browsing
- category browsing
- profile or account navigation

When a notification opens an Event Detail screen, the user should still be able
to navigate naturally back toward today's Home screen where practical.

---

## 10. Imagery and Iconography

Historical images should support the event rather than decorate the interface.

Use images when they are:

- relevant to the event
- visually legible at mobile sizes
- legally usable with proper attribution metadata
- strong enough to improve the feature or detail treatment

Avoid event-specific decorative icons in the core template. For example, crossed
swords may work for a battle but will not generalize to inventions, discoveries,
cultural events, disasters, treaties, or political changes.

Prefer reusable, neutral iconography:

- back arrow
- chevron
- external-link icon
- source/read-more icon when needed

---

## 11. Accessibility

Accessibility is part of the v0.0.1 design.

Requirements:

- maintain strong text contrast against warm paper and ivory surfaces
- use readable body text sizes
- keep tap targets comfortable on mobile
- avoid relying on color alone to communicate tap behavior
- support dynamic text sizes where practical
- ensure source rows and event rows are accessible tap targets
- provide useful alt text or semantic labels for event images

Decorative dividers, rules, and image frames should not interfere with screen
reader order.

---

## 12. Out of Scope for v0.0.1 Design

Do not design or implement:

- search
- arbitrary date picker or calendar browsing
- timelines
- categories or filters
- accounts, login, or profiles
- personalization
- bookmarks or saved events
- sharing
- comments, likes, or community features
- streaks, badges, points, or other gamification
- quizzes
- AI chat or runtime AI explanations
- multiple notification types
- notification schedule settings
- long-form article templates

These features may be considered later only if they support the product after
the daily-history loop is validated.

---

## 13. Reference Screen Direction

The canonical v0.0.1 screen references are:

- `docs/design/home.png` — Home screen reference.
- `docs/design/event_details.png` — Event Detail screen reference.

Use these images as the primary visual references when implementing or
reviewing the v0.0.1 UI. The written guidance in this document explains the
intent behind those screens and should be used to resolve responsive,
accessibility, loading, error, or no-image states that are not shown directly in
the static references.

The current approved direction uses:

- centered "On This Day" masthead
- warm paper full-screen background
- soft ivory editorial panels
- thin borders rather than heavy shadows
- archival cobalt date/year metadata
- muted copper horizontal rules
- large black serif event titles
- restrained sans-serif body copy
- compact additional-event rows with cobalt years
- simple back arrow and external-link affordances

This direction should be treated as the baseline for v0.0.1 implementation.

Future design iteration should refine spacing, typography, image proportions,
and accessibility while preserving the product scope and editorial personality
defined here.

## 14. Quiz v0.1.0

### Root navigation and setup

Use a compact Today/Quiz bottom navigation bar on the two roots. Preserve the
centered editorial masthead and Today date. Event Detail, gameplay, results,
and review sit above the root shell without bottom navigation. Keep the native
back affordance and existing notification destinations.

Quiz offers Daily Challenge and Quick Play with a clear mode hierarchy. Use
segmented controls for 5/10/20, a switch for Quick Play timing, and grouped
selection rows for collections. Unsupported counts are visibly disabled and
semantically explained; do not silently change count when collection changes.
Show Daily date, duration, and official/practice status before play. Defaults:
five questions, Mixed for Quick Play, Quick Play timing enabled.

### Gameplay composition

Retain warm paper, ivory, deep ink, cobalt, pale stone borders, and sparse copper
accents. Use a compact progress/timer row, readable editorial question heading,
image where required, and stable answer rows. Avoid poster-sized text, nested
cards, heavy shadows, decorative medals, and celebratory score systems. Existing
Material icons suffice; letter spacing stays zero. Subtle transitions must
respect reduced-motion preferences.

Choice rows commit on tap for multiple choice, true/false, and image questions.
Immediately lock them and show selected/correct/incorrect states using text and
icons as well as color. Do not render Submit answer. True/False retains API
order. Ordering uses four movable rows with drag handles and accessible up/down
actions, followed by Submit order.

Daily feedback shows compact correctness and the correct answer/order, with
Continue readily available. Do not put full explanations or external sources
between Daily questions: its total timer continues. Quick Play feedback may
show explanations and source rows, with its timer stopped until Continue.
On the final question, completion/save already occurred before Results is opened.

### Images and accessibility

Prepare required images before showing a timed question. Loading/retry states
must not expose a running timer. Use an inspectable image with preserved aspect
ratio and contain fitting where cropping would remove information. Follow the
Architecture resource budgets; no gallery or image-cache package is required.
Required-image failure never consumes score or silently changes the assignment.

Use neutral alt text and retain accessible attribution/license information;
do not expose the full technical URL as an image semantic label. Provenance
links may identify the subject, which is acceptable for this trusted casual
experience; do not falsify attribution to conceal it. Full review includes image
credits and sources. Image questions offer Skip question, recorded as unanswered
with zero credit. This does not make visual recognition equivalent for blind
users; retain that limitation in accessibility review.

All controls need comfortable targets (at least 48 logical pixels), meaningful
labels, logical focus order, and large-text layouts without overlap. Ordering
must be operable without dragging. Announce correctness and meaningful timer
thresholds rather than every tick. Let question/feedback content scroll while
keeping Continue reachable, including at large text scales. Avoid communicating
state through color alone.

### Results and review

Show correct/total, percentage, answered/correct/unanswered counts, and official
or practice status where applicable. Review every question, including timeouts,
skips, and questions never reached, with user answer, correct answer, explanation,
external sources, and image provenance. Difficulty stays secondary; there are no
speed bonuses. Present save progress/failure without hiding the completed result,
and offer retry for an unsaved frozen result.

### Failure and interruption states

Provide loading, unavailable/empty, retryable request failure, invalid-content,
image preparation failure, and unsaved-result treatments. Back during unfinished
play requests abandonment confirmation while timing continues. Quick Play expiry
waits in feedback; Daily expiry completes and makes review available. No timed
screen should auto-advance through unseen questions after backgrounding.

The existing home.png and event_details.png remain canonical for Today and Event
Detail. Quiz inherits their visual language, not their exact article composition.
Verify each quiz type, feedback, results, and errors on small screens, at large
text scales, and with screen readers before release.

### Reviewed Stitch references (2026-09-11)

The eight named exports under `docs/design/` are supporting visual proposals.
Read [QUIZ_SCREEN_REVIEW.md](design/QUIZ_SCREEN_REVIEW.md) for their filename index,
per-screen corrections, missing states, and concrete timer presentation rules
before implementing any quiz screen. Written product/interaction requirements
and that correction list take precedence over conflicting screenshot details.
The exports have not been edited to incorporate the corrections.

Use their palette, serif/sans pairing, root navigation and answer-row structure.
Do not copy impossible countdowns, automatic next-question transitions,
submission at zero seconds, invented metadata/assets, profile actions, or
selected-answer styling for a skipped question. Daily shows total remaining
time; timed Quick Play shows current-question remaining time. Both derive from
session state and backend metadata. Untimed play and image preparation have no
running countdown. Distinguish question progress from time and score.

Keep gameplay compact, remove decorative pre-question blocks, wrap option/item
text completely, and keep feedback/submit actions reachable above the safe area.
Use the existing home.png and event_details.png for history content; the Stitch
Today export is a bottom-navigation reference only. Missing quiz screens should
reuse the approved components and written requirements, with real-device review
during MQ4-MQ11 rather than requiring another complete design generation pass.
