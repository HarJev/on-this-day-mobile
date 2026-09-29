# On This Day: Production Launch Workplan

Status: proposed execution plan, not an implementation record. Updated 2026-09-26.
Owner repositories:

- Mobile: `/Users/jevaunharris/Workspace/on-this-day/on-this-day-mobile`
- Backend: `/Users/jevaunharris/Workspace/on-this-day/on-this-day-backend`

This is the handoff for the next Codex task. Read `AGENTS.md` in each repository,
the relevant product/architecture documents, and `docs/RELEASE_READINESS.md`
before editing. Preserve all existing uncommitted work. Present the focused plan
for a task and wait for review before code changes, as both repositories require.
Execute one task at a time; do not deploy, buy a service, import into production,
commit, push, or silently change product rules without explicit approval.

## Snapshot And Decision

The numeric snapshot below is historical evidence from its stated date, not the
current content-status authority. Later L6/L7 batches changed the repositories
and local database. Refresh counts and fingerprints through the approved status
workflow before making a release decision.

As checked locally on 2026-09-16: 96 published quiz questions, 88 historical
events, and 23 curated calendar dates are in PostgreSQL and canonical JSON.
September 16-30 have one featured and one additional event each. The Q8 target
is 240 questions. Most dates, including October, have no curated content yet.
These counts must be refreshed before implementing later tasks.

Quick Play's API returned 200, but native image preparation received HTTP 429
from `upload.wikimedia.org`. Session preparation correctly failed before timing
or scoring. A device cache does not solve the first request for an uncached
image. Real-image iOS and Android checks are required; fixture-image tests do
not prove delivery.

Daily Challenge already uses a date-seeded question selection, persists one
worldwide 20-question assignment per date, and returns stable 5/10 prefixes.
Repeated requests on the same date must remain identical. Observed adjacent-day
overlap in the small current bank was 0-1 in the first five and 3-8 in the full
20. Growing the bank precedes any selector redesign.

**Recommended image architecture:** keep the existing bounded session decode;
add a bounded, disposable **on-device disk cache of encoded image bytes**. It
works identically with SAM and a deployed HTTPS API and adds no cloud storage
bill. Fix request identity and rate-limit handling for cache misses. For public
release, prefer a small **owned static-image origin** rather than depending on
live Wikimedia hotlinks. The lowest-operations AWS option to evaluate is a
private S3 bucket behind CloudFront with Origin Access Control, immutable
reviewed renditions, and CDN URLs in imported image records. No image proxy
Lambda or public-write bucket. Do not provision it before a price/eligibility
check and user approval. Initial fixed quiz images could instead be bundled in
the app at zero new infrastructure cost, but every later image-question batch
would require a mobile release; bundling is a fallback, not the preferred
ongoing publishing path.

AWS currently advertises a $0/month CloudFront flat-rate Free plan with 1M
requests, 100GB transfer, and 5GB of S3 storage allowance, but **Free Tier
accounts cannot use flat-rate plans**. Separately, CloudFront pay-as-you-go
currently includes a monthly free allowance of 1TB transfer and 10M requests;
S3 requests/storage and other services have their own billing rules. Account
eligibility and actual costs must be checked. Never promise zero cost or switch
plans automatically. Create a cost estimate and budget alert before provisioning.
See the official [CloudFront pricing](https://aws.amazon.com/cloudfront/pricing/),
[pay-as-you-go allowance](https://aws.amazon.com/cloudfront/faqs/),
[plan requirements](https://docs.aws.amazon.com/PricingPlanManager/latest/UserGuide/plans.html),
and [S3 origin-access guidance](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html).
Wikimedia [allows reuse subject to each image's license but discourages
hotlinking](https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia/technical).
Keep source-page, creator, attribution, license, license URL, and alt text even
when the served image URL changes. Follow Wikimedia's
[User-Agent policy](https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_User-Agent_Policy)
and rate limits while any source-host downloads remain.

## Release Stages

| Stage | Minimum bar | Claim |
| --- | --- | --- |
| Local/internal MVP | Current API and bank, known date coverage, no-score-loss image failure | Suitable for hands-on testing only |
| Closed beta | Reliable first-image load, deployed HTTPS API, 90 consecutive upcoming curated dates with at least four strong total events per date and roughly 150 reviewed questions | Limited audience with an owned content publishing schedule |
| Public v1 | All 366 month/day slots have a sourced featured event and at least four strong total events, with five or more where warranted; 240 reviewed questions; owned image delivery or an equally demonstrated first-fetch solution; production deployment and native release gates below | Daily return experience without predictable missing-date failures |

There is no upper cap on worthwhile events. Do not weaken historical accuracy
to hit a count. Exceptionally, a reviewed date may have fewer than four strong
events, but that requires an explicit editorial exception rather than becoming
the default. No runtime AI-generated history or quizzes.

Task evidence is not a single pass/fail flag. For each task, report separately:
**implementation**, **automated verification**, and **native/manual verification**,
each as PASS, FAIL, or PENDING with the specific environment and evidence. An
unavailable simulator does not invalidate completed implementation; unit tests
do not imply a real image loaded on a device. A task can be implementation-
complete while its public-release gate remains open.

## Ordered Tasks

### L1. Make Image Cache Misses Reliable (Mobile, P0)

Inspect the existing `HttpQuizImageDownloader`, preparer, tests, and the 429
response. Give outbound source-host requests an identifiable application
User-Agent/contact and honor `Retry-After` or a short bounded backoff on 429.
Coordinate 429s with a lightweight **per-host cooldown** scoped to the
preparation/download client: concurrent requests to one throttled host must
not independently retry in a stampede. New requests observe the cooldown.
If the requested delay exceeds the remaining image/batch time, fail rather
than sleeping past the deadline. Backoff waits are cancellable. Network,
retries, backoff, and **decode** all fit within the existing 15-second per-image
and 60-second per-batch failure ceilings; these are not acceptable normal
startup durations. Log host, status, failure kind, retry decision, and total
preparation duration without tokens or full query strings. A failed required
image still stops preparation before timing and does not score a question.

Implementation: identifiable requests, host-scoped cooldown, cancellable
bounded retries, safe failure and duration diagnostics. Automated verification:
focused tests cover 200, concurrent 429s with/without Retry-After, a delay
longer than the remaining budget, cancellation during backoff, timeout, decode
budget, and non-retryable errors. Native/manual verification: run first-fetch
Quick Play with real images on iOS and Android, not only fixtures, and record
each platform separately. If 429 still occurs, report it rather than claiming
that retries fixed delivery.

### L2. Add A Bounded On-Device Cache (Mobile, P0)

Cache **encoded bytes**, not `ui.Image` handles, under the OS-managed app cache
directory. Use a URL/content-version SHA-256 key, atomic writes, a maximum of
64 MiB on disk as an adjustable initial limit, least-recently-used eviction,
and discard/re-fetch for corrupt entries. Use a small explicit last-access
index or entry metadata rather than filesystem access times. The index and
files are disposable/reconstructible: missing or corrupt index -> rebuild;
missing entry -> miss; corrupt entry -> delete and fetch; orphan file -> reclaim
during maintenance; OS clears all files -> normal cold miss. No result, progress,
assignment, editorial content, or answer state depends on cache persistence.
Coalesce simultaneous callers for the same key into **one disk lookup and, on
miss, one network download and atomic write**. Cancellation of one caller must
not corrupt the shared result or another active caller. Cache only successful
HTTPS 200 static images that pass existing size and decode validation; never
cache 429/error bodies. Reapply the 8 MiB/image,
32 MiB encoded/session, 1024-pixel edge, and 32 MiB decoded/session limits on
cache hits. The existing session image handles still release on exit. Cache
eviction must not delete quiz results. A cache miss uses L1's network path.

Start with required quiz images. Then reuse the same storage primitive for
optional Today/Event Detail images, where failure simply omits the image and
never blocks history text. Do not add a generic image package that bypasses
quiz bounds. Do not promise offline quiz play: API definitions and new images
still require connectivity.

Implementation: bounded, self-healing encoded-byte cache and same-key
single-flight. Automated verification: cold fetch, warm no-network hit, URL
change, corrupt/missing index or entry, orphan cleanup, size/LRU eviction,
concurrent callers, app restart, and OS cache deletion. Native/manual
verification: demonstrate cache miss and warm hit on both platforms as
available; verify local SAM and deployed-URL configuration use the same mobile
cache path without promising offline quiz play.

### L3. Prepare Owned Image Delivery (Backend/Infrastructure, P0 Before Public)

Compare (a) CloudFront flat-rate Free eligibility with private S3, (b)
CloudFront pay-as-you-go plus its applicable free allowance and separately
billed S3/other services, and (c) bundling the fixed initial image bank.
Recommend S3 + CloudFront for content updates after launch if the owner accepts
the estimate. This task may
produce infrastructure code and a dry-run asset-publishing command, but must
**not provision resources or incur charges without separate approval**. Apply
an explicit IAM deny of `pricingplanmanager:ApprovePaidSubscription` to
agent/deployment roles; paid-plan approval is a manual owner action. AWS
documents that this action
[activates billing](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-pricingplanmanager-subscription.html).

Publishing workflow: fetch a reviewed, licensed source rendition once; verify
content type, dimensions, encoded size, checksum, and rights; upload an
immutable, hash/versioned object; preserve the original media URL in an
editorial manifest and Commons/source-page/license metadata in curated JSON;
make `image.url` point to the owned HTTPS rendition. Use long cache headers for
immutable keys. Existing question IDs and completed Daily assignments must not
change. No dynamic API/Lambda image proxy or source-site hotlinking in the final
public path. Support a local pre-publication check without requiring AWS by
validating bytes/manifest, while the mobile disk cache remains origin-agnostic.

Implementation: cost/eligibility comparison, approval-gated infrastructure,
immutable asset publishing, provenance and safe missing-object behavior.
Automated verification: manifest/checksum/size/license checks and URL mapping
without AWS access, plus integration checks where approved infrastructure exists.
Native/manual verification: every published quiz image loads on first install
on iOS and Android without fixture mode, a correction uses a new key, and
provenance remains visible. Extend owned delivery to optional event images
when available. An unapproved infrastructure decision remains PENDING, not
silently implemented.

### L4. Ratify The Event-Count Policy (Both Repositories)

The proposed editorial **floor is four total events per date**: one featured
plus at least three additional. Aim for five or more when the events are
interesting and well sourced. There is **no upper cap**; retain every strong
addition that improves the day's reading experience. This replaces the old
aspiration of 6-10 *additional* events as a rigid target, but does not forbid
six or more additions. Update Product, Decisions, Design/architecture where
relevant, and the mobile layout expectation. The backend validator currently
warns below six additional events; change warning/reporting to flag fewer than
four total and highlight editorial exceptions without forcing weak padding.
Preserve the required featured event, sources, unique IDs, notification copy,
and date validation.

Implementation: docs, validator warning, content report, and UI expectations
agree; fewer than four is an editorial warning/exception, not a schema error.
Automated verification: validator/report tests distinguish valid, below-floor,
explicit exception, and missing day. Native/manual verification: inspect a day
with many worthwhile events and one with an editorial exception; neither
silently truncates or pads content. No automatic deletion of imported content.

### L5. Build A Repeatable Editorial Content Pipeline (Backend)

Use the existing `content/events.json`, `content/daily-events.json`,
`content/quizzes/questions/*.json`, strict validators, and transactional
importers. Add a **draft/candidate stage outside importer inputs** and a
machine-readable coverage report: missing month/days, dates below the four-
event floor, five-plus-event counts, source/link status, potential duplicate
events, featured copy, image licenses, quiz counts by
type/difficulty/region/era/collection, and adjacent-day quiz
overlap. Candidate gathering and copy drafting may be assisted, but every
published claim/answer/date/source/distractor/license gets human review.
Never scrape a source into production JSON or auto-publish generated prose.

The publish path is: candidate -> direct-source verification -> editorial
review ledger -> canonical JSON -> validator -> staging import/smoke -> approved
production import -> post-import coverage check. Idempotent import is not a
substitute for a DB backup or review. Import only touched batches; preserve
omitted events/questions and immutable Daily assignments. Report source URL
failures as review work, not silent URL substitution.

"Direct-source verification" means opening the cited page or document and
confirming it directly supports the exact published claim. It does **not**
require an ancient primary source for ancient history. Search snippets, AI
output, Wikipedia summaries, and aggregator lists are research leads, not
the final supporting citation. Keep an auditable editorial ledger with candidate
ID, canonical ID, review status/date, source-check date and URLs, reviewer notes,
and image-rights status. The ledger need not be part of the public API or JSON.

Implementation: a new 7-day event batch and a 20-30-question quiz pack can each
be reviewed and imported without hand-editing SQL. Automated verification:
format/schema/coverage checks and idempotent staging import/smoke. Manual
verification: human review and source/rights ledger entries are complete
before publishing. No CMS, public mutation API, or runtime AI is required.

### L6. Expand Daily Events (Backend Content)

First raise September 16-30 from two to at least four total events/day, aiming
for five or more when strong choices exist. Then cover the immediately upcoming
months. Fill September 1-14 for calendar completeness. Work in seven-day,
reviewable batches, with directly checked supporting sources and
globally varied, non-trivial events; images are optional. Keep one editorial
featured choice and concise curiosity-driven notification copy per date.
Avoid questionable dates, vague summaries, unsourced claims, and repetition
solely to meet a quota.

Milestones: (1) 30 consecutive days ahead; (2) 90 consecutive days ahead for
closed beta; (3) all 366 month/day slots for public v1. A rolling runway is an
operational commitment, not a substitute for full-year coverage. Review the
coverage report after every batch and maintain a forward buffer until the
366-day goal is reached.

Implementation: each batch adds reviewable canonical JSON and explicit
exception notes where needed. Automated verification: JSON validation,
idempotent local/staging import, post-import coverage, and targeted Today/Event
Detail smoke. Manual verification: directly checked sources and editorial
review. Do not run large application suites for every content-only batch unless
a rule or code changed.

### L7. Expand The Quiz Bank And Measure Daily Variety (Backend Content/Code)

Grow the reviewed bank toward and beyond the 240-question checkpoint in reviewable 20-30-question packs; audit current totals before each batch.
The existing target at 240 is 144 multiple choice, 36 true/false, 36 image
identification, and 24 chronological; current counts must be rechecked before
allocating packs. Curated events are a useful **research lead**, not an
automatic question generator. Turn only clear, interesting facts into questions
with a directly supporting source, plausible unambiguous distractors, a short
explanation, balanced global/era coverage, and no near-duplicate prompt.
Chronological order needs independently verified dates; new image questions
must go through L3's rights/asset pipeline before publication. Use the existing curated relatedEventIds relation for reviewed links. Prioritize natural hooks from upcoming featured/additional events, reusing suitable published questions before creating new ones. Skip obscure or forced hooks; Daily should feel like discovery, not homework. Follow ../on-this-day-backend/docs/CONNECTED_QUIZ_CONTENT_PLAN.md (C1-C4). The 240 target is not a ceiling, and event coverage and linked-question coverage are separate gates.

Keep the present date-seeded, globally stable Daily assignment. Add regression
and reporting for distinct dates, fixed-date repeatability, 5/10/20 prefixes,
concurrent first requests, retired questions, and adjacent-day overlap. After
the bank reaches at least 240, consider a versioned **soft** recent-question
penalty only if measured overlap remains poor. Pre-generate upcoming dates in
date order if prior assignments affect selection; never let request order,
timezone, or a client's random seed change an already assigned date. Relax
the penalty when type/difficulty supply is insufficient rather than failing
the day. Aim for no repeat in adjacent first-five sets and at most four shared
questions in adjacent full-twenty sets where the bank permits; report exceptions.

Implementation: 240 sourced published questions, playable collections, all four
types, and unchanged official-result semantics and completed assignments.
Automated verification: content distribution, selector concurrency/prefix,
overlap report, import, and API smoke checks. Native/manual verification:
editorial/source/asset review and real-image first fetch on available devices;
record unavailable devices as PENDING, not PASS.

### L8. Production Infrastructure And Native Release Gate (Both Repositories)

Execute L8 as separate reviews, not one implementation prompt:

- **L8a - Infrastructure and cost:** estimate and approve API, database,
  storage/CDN, logs, transfer, backups, staging and production. Restrict agent
  roles with an explicit deny on `pricingplanmanager:ApprovePaidSubscription`
  and any other
  unapproved paid-plan action.
- **L8b - Deployment and operations:** implement the approved IaC, secrets,
  migrations/import order, backup/restore drill, access controls, alarms and
  runbooks. Deploy only after a separate owner go-ahead.
- **L8c - Native distribution:** signing, release configuration, Firebase/APNs,
  store/privacy materials, physical-device performance/accessibility checks.
- **L8d - Release evidence:** independently mark infrastructure, 366-day/event
  coverage, 240-question/asset coverage, and native flows PASS/FAIL/PENDING.
  An overall public-release decision requires all required gates to pass or an
  explicit owner-approved scope change.

Only after separate approval, add the smallest production infrastructure
consistent with the existing Lambda/API Gateway/PostgreSQL/Firebase direction.
Cost the database, API, static media, logging, and data transfer separately;
static-image cost is not the full service cost. Use IaC, HTTPS, least-privilege
secrets/IAM, Flyway before import, DB backups/restore drill, logs/alarms,
rate-limit protection, and staging vs production configuration. Do not deploy
to the user's AWS account or create paid resources merely by executing this
plan. Confirm notification scheduling or explicitly de-scope it for the first
release; local token registration alone is not daily notification delivery.

Prepare signed iOS/Android builds, non-local API configuration, Firebase/APNs
ownership, privacy/store materials, and physical-device checks. Run cold and
cached image flows, Today in different timezones and on an uncovered-date
simulation, Quick Play all types/counts, Daily 5/10/20 and date rollover,
results after restart, background timers, external sources, VoiceOver/TalkBack,
and network-loss behavior. Keep an explicit release checklist with evidence
and unresolved risks; do not call a local SAM demo production-ready.

## Post-Audit Launch Tasks

The independent audit and owner review accepted the following work. These tasks
extend L1-L7; they do not erase completed checkpoints or imply implementation.
Run each task as a separately reviewed change.

### A1. Close Demonstrated Reliability Blockers (Mobile, P0)

- Safely follow a bounded number of HTTPS image redirects while reapplying host
  cooldown, timeout, cancellation, encoded-byte, and decode limits. Never follow
  an HTTPS-to-HTTP downgrade. Prefer final reviewed rendition URLs and require a
  real first-fetch check for every published image.
- Reproduce the reported current-Xcode iOS deployment-target failure before
  editing Pods. If reproduced, apply the smallest Podfile/build-setting fix and
  verify a simulator build. Earlier successful builds do not invalidate a new
  demonstrated toolchain failure.
- Render usable UI before notification consent. Split notification bootstrap,
  existing authorization/token lookup, and the first permission request.
- Provide an honest unavailable-content state rather than a technical error or
  blank screen.

### A2. Connect Today And Daily (Backend And Mobile, P0 Product)

Add a curated many-to-many event-question relation using stable IDs. Extend quiz
ingestion, validation, schema, repositories, and coverage reporting. Never infer
the relation from prompt text at runtime. For newly generated assignments:

- reserve one eligible featured-event-linked question in Daily-5 when available;
- allow at most one additional same-date linked question in Daily-10/20;
- fill all other positions with the existing balanced global selection;
- use deterministic fallback when linked supply is absent or incompatible;
- preserve stable 5/10/20 prefixes and every existing persisted assignment.

Expose only the metadata needed for Event Detail, Daily setup, Results, and
Review to link the learning loop. The client continues local grading. Add exact
selector tests for linked availability, no-link fallback, balance, concurrency,
date repeatability, and assignment immutability.

### A3. Add A Seven-Day Recent Window (Backend And Mobile, P1)

Expose today plus the previous six calendar days using backend timezone/date
resolution, including year and leap-day boundaries. Return only curated content
and distinguish a partially covered window from an API failure. Add a restrained
Recent section and event-detail navigation; do not add arbitrary date search or
a complete archive. Past quiz play is practice and never replaces an official
Daily result.

### A4. Complete Daily Notification Delivery (Backend And Mobile, P0 Retention)

Implement the deferred scheduled notification handler and EventBridge/runtime
wiring behind the existing sender. Resolve devices by local date/timezone and
isolate each group: unavailable content or one send failure must not abort other
groups. Preserve idempotency and permanent/transient token handling.

On mobile, request permission only after a value explanation. Keep the app fully
usable after denial. Add a checked-in debug local notification and iOS simulator
`simctl push` fixture for routing tests. Verify Android remote FCM separately.
Physical iOS FCM/APNs remains pending until owner-controlled Apple credentials
exist; no simulator result may be reported as that pass.

### A5. Strengthen Editorial Quality And State Reporting (Backend, P0 Content)

Extend authoring validation/reporting to cover:

- correct-option positions for multiple-choice and image packs, without treating
  position as correctness;
- distractor semantic class, comparable specificity, prompt answer leakage,
  duplicate/overlapping options, and obvious outliers through human review;
- explicit related event IDs;
- draft, `source_verified`, approved canonical, and imported database counts;
- canonical/database content fingerprints and stale-import detection;
- featured-image search/right-review outcome and coverage.

Drafts stay outside importer discovery and runtime PostgreSQL. Audit existing
published packs under the same rules before public release. Do not automatically
rewrite historical copy or distractors without editorial review.

### A6. Expand Event Imagery And Content Runway (Backend Content, P1)

Continue seven-day event batches with at least four strong events per date and
more where warranted. Every featured-event review includes image research;
prioritize useful featured imagery, preserve provenance, and record why a date
remains text-only. Maintain 30-day, then 90-day, then 366-date milestones. Keep
quiz expansion moving toward 240, including high-quality related questions,
recognizable-but-fair images, and improved older distractors.

### A7. Add Minimal Observability (Both Repositories, P1 Before Beta)

Choose a privacy-conscious crash and product telemetry approach before beta.
Measure Today/detail views, Daily and Quick Play starts/completions, categorized
image preparation failures, notification prompt/result/open, Recent use, widget
opens, and shares. Do not collect answer text, notification tokens, full image
URLs/query strings, or unnecessary personal identifiers. Document retention,
consent, and store/privacy disclosures before enabling production collection.

### A8. Add Widget And Share Cards (Mobile, P2)

After A1-A4 are stable, add an iOS/Android home-screen widget backed by a cached
app-owned featured-event snapshot with current, stale, and empty states. Tapping
opens Event Detail. Add restrained event/result share cards; include an image
only when its reviewed rights permit redistribution in generated media. Neither
feature may introduce an account requirement or block the core app.

### A9. Visual Refresh From Claude Design (Mobile, P1 Before Beta)

Implement DESIGN.md section 16 as one design and typography pass, following
`design/claude-design/phase-1/` and `phase-2/` and the corrections in
`design/claude-design/REVIEW.md`. There are no behaviour, API, or scoring
changes. In order:

1. Tokens and theme. Add the new colours to `AppColors`. Bundle Source Serif 4
   and Public Sans. Build one `TextTheme` from the section 16 scale with zero
   letter spacing. Set the button, switch, tab bar, and bottom sheet themes.
   Replace the per-widget `Georgia` overrides.
2. Quiz: the header, type identity, AnswerRow, True/False tiles, OrderRow
   timeline, sticky FeedbackPanel, Sources row and sheet, Results strip and
   stats, "Worth revisiting", and Full review cards.
3. Today and Event detail: the featured card, list rows, Recent days rows,
   image caption credit, collapsed Sources, quiz link row, skeleton loading,
   error cards, and the notification explainer sheet.
4. Motion per section 16, with reduced-motion fallbacks.

Verify with widget tests for each state. Capture normal-phone
screenshots of each handoff screen and compare them. Check large text and
reduced motion. The empty-day card stays parked with the empty-day fallback.

Status (2026-09-28): steps 1 to 3 are implemented on branch
`claude/design-typography-pass-joozy2`, with widget tests and screenshot
captures for Today, Event detail and every Quiz screen. Motion keeps the
existing transitions, and every new expand/collapse drops to no animation under
reduced motion. Still open: an on-device check of large text and reduced motion.
Deliberate differences from the mockups: ordering rows show no years (the API
sends none), Quick Play feedback keeps its explanation inline above a sticky
outcome summary so Continue stays reachable at large text, "Your choice" and
"Practice again" keep the app's copy, and the notification explainer is
restyled in place.

## Suggested Execution Order

Completed L1-L5 foundations remain in place; L6/L7 content work continues in
reviewed batches. Next execute A1, then A5's status baseline, A2, A3, and A4.
A6 continues in parallel without mixing content approval into code tasks. Add A7
before closed beta, then A8. L8 cost/design review may proceed early, but resource
provisioning, paid services, native distribution, and public release remain last.
Stop after each task for review; do not blend reliability fixes, editorial
promotion, product expansion, and deployment into one checkpoint.

## Handoff Prompt

> Read `/Users/jevaunharris/Workspace/on-this-day/on-this-day-mobile/docs/PRODUCTION_LAUNCH_WORKPLAN.md`
> and both repositories' `AGENTS.md`. Work on task **A1 only**. Inspect the
> existing dirty worktrees, state a focused implementation plan for my review,
> and do not edit code until I approve it. Preserve unrelated changes. After
> approval, implement, verify with a real iOS and Android first-image request
> when available, and leave the task uncommitted for review. Do not start A2,
> change backend content, deploy, or incur cloud costs.
