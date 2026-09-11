# Quiz Stitch Reference Review

Reviewed 2026-09-11 against DESIGN.md section 14, PRODUCT_DECISIONS.md
PD-020 through PD-032, and quiz_implementation_plan.md. These are visual
proposals with required corrections, not pixel-perfect implementation targets.
The images were renamed without changing their pixels. Screenshot text and
images are illustrative; production content and provenance come from the API.

## Reference Index

| Original filename | Descriptive filename | State and assessment |
| --- | --- | --- |
| screen.png | [stitch_today_root_bottom_nav.png](stitch_today_root_bottom_nav.png) | Today root; navigation reference only |
| screen 2.png | [quiz_true_false_quick_play_timeout.png](quiz_true_false_quick_play_timeout.png) | Quick Play true/false timeout; behavioral corrections required |
| screen 3.png | [quiz_hub_uncompleted.png](quiz_hub_uncompleted.png) | Quiz hub before completion; usable with layout/copy corrections |
| screen 4.png | [quiz_hub_completed.png](quiz_hub_completed.png) | Quiz hub after official completion; usable with simplification |
| screen 5.png | [quiz_multiple_choice_daily_answering.png](quiz_multiple_choice_daily_answering.png) | Daily choice answering; timer/content/layout corrections required |
| screen 6.png | [quiz_image_daily_skipped.png](quiz_image_daily_skipped.png) | Daily image skipped feedback; timer/outcome/asset corrections required |
| screen 7.png | [quiz_daily_setup.png](quiz_daily_setup.png) | Daily setup; closest to approved behavior |
| screen 8.png | [quiz_ordering_quick_play_arranging.png](quiz_ordering_quick_play_arranging.png) | Quick Play ordering draft; timer and truncation corrections required |

## Shared Implementation Corrections

- Preserve warm paper, ivory, ink, cobalt, sparse copper, serif headings and
  sans-serif answers. Remove profile icons, LIVE QUESTION labels, decorative
  category metadata, explanatory gesture captions, heavy shadows and excessive
  letter spacing. Use ordinary labels such as Correct, Time's up, and Continue.
- These tall exports do not establish viewport fit. Use a compact masthead,
  safe-area-aware body and moderate question headings (start around 24-28 logical
  pixels at normal text scale). Keep answers readable and allow natural wrapping.
  Avoid the article-sized headings that push answers far below the fold.
- Keep question progress and mode/time status visible during scrolling. Use one
  thin progress bar with a text position, rather than 20 narrow segments. The bar
  represents question position, not score or time. Keep feedback actions in a
  safe-area footer with body padding so they do not obscure content.
- Answer rows commit on tap and lock immediately. Do not use pre-answer check/X
  icons that imply correctness or radio selection followed by a missing submit.
  Only ordering has Submit order. Label post-answer selection and correctness
  separately, using icons and text as well as color.
- Use no bottom navigation above the two roots. Provide abandonment confirmation
  for leaving unfinished play; timing continues during that confirmation.
- Use real backend content, sources and licensed images. Do not import explanatory
  subtitles, historical claims, topic hints or image credits invented by Stitch.
  No factual/source verification was performed on screenshot-only content here.

## Timer Presentation Contract

Use actual response timer metadata and session state; never copy screenshot times.

| State | Display and behavior |
| --- | --- |
| Daily answering/feedback | `Total time 01:32`; one remaining duration for the session, continuing between questions and in the background |
| Quick Play answering | `Question time 00:18`; current question only; initial defaults are 20s choice/true-false, 30s image, 45s ordering |
| Quick Play submitted feedback | Replace active countdown with a quiet stopped state or omit it; wait for Continue |
| Quick Play timeout | `Time's up`, locked input, correct answer and feedback, explicit Continue; never timed auto-advance |
| Untimed Quick Play | No countdown; optional quiet Untimed mode label |
| Image preparation | Preparation status with no running timer |
| Daily expiry | Freeze/save once and show completion/results access; no answer or order submission remains active |

Use fixed-width/tabular timer digits to prevent horizontal movement. At five
seconds remaining, add a restrained warning treatment and accessible threshold
announcement; avoid flashing or announcing every tick. A five-question Daily
starts at 02:00, ten at 04:00 and twenty at 08:00 under the current contract.
Use a valid example such as 01:32 for question 2 of 5 and 01:05 for question 3
of 5. Quick Play ordering should show e.g. 00:38 while Submit order is active,
not the export's 00:00. At the deadline, expiration wins over late submission.

## Per-Screen Review

### Today Root

Keep only the root navigation pattern from stitch_today_root_bottom_nav.png.
home.png and event_details.png remain canonical for history screens. Do not
copy the new read-time badge, FEATURED ARCHIVE, fixed event count, extra location
lines, rewritten content, or reduced featured-title hierarchy. Keep the full
featured surface tappable and additional events as compact rows. Use the existing
Today date placement and standard accessible navigation icons.

### Quick Play True/False Timeout

Remove the decorative printing image, ARCHIVAL INQUIRY and FACT VERIFICATION
blocks. The API true/false model has no image; the preview can also reveal the
answer. Render just the prompt and canonical True/False labels before answering.
Remove invented explanatory text from both choices. After timeout, both are
disabled; mark True as Correct answer without implying it was selected. Replace
Archival consensus with Time's up / Correct answer: True. Render the backend
explanation and individually tappable named sources with external-link icons.
Replace Next Question in 2s with Continue. Keep it reachable without scrolling
through the entire explanation. Design the unanswered state from the same view,
without feedback or pre-revealed answer indicators.

### Uncompleted Hub

Keep the two clear mode choices and stronger Daily action. Fix the Quiz heading
being clipped beneath the masthead. Reduce repeated dates and large vertical
gaps so both choices are discoverable on a normal phone. Prefer unframed sections
separated by a rule over large floating panels. Use Daily Challenge as the main
heading, not a pill, and plain text for Official attempt available instead of a
medal. Use Choose challenge or Daily Challenge for the action leading to setup;
the actual Start action belongs after configuration/preparation. Shorten Quick
Play copy and remove the hard-coded 60-question archive claim (or derive a count
from the catalog only if it adds value). Daily is a mixed set assigned to the
date, not history that happened on that date.

### Completed Hub

Keep the score, Review answers and Practice again. Reduce the repeated August 22
and oversized challenge title. Remove the score progress bar: it resembles an
unfinished task and duplicates the score. Omit Completed in 3m 18s unless elapsed
duration is deliberately modeled and measured; never invent it or derive it from
a wall-clock completion timestamp. Keep this optional metric out of the initial
implementation. Say Later attempts are practice in brief supporting text only
where needed. Remove custom questions and at your own pace from Quick Play copy;
users choose existing collections and timing defaults on. Match the uncompleted
hub's spacing and Quick Play action style. Only label a result official when
saved classification confirms it; pending/failed saves need a truthful state.

### Daily Multiple Choice Answering

The 03:12 timer is impossible for five questions; use the Daily total contract.
Remove the invented city image, era strip and ANCIENT GEOGRAPHY label: this is
a text question and the model supplies no such image or hint. This also brings
the question and four answers into comfortable reach. Keep option rows and their
presentation order; optional A-D labels are visual positions, not answer IDs.
Remove the gesture instruction at the bottom. Tapping commits immediately and
reveals compact Daily feedback with Continue. Do not add Submit answer.

### Daily Image Skipped Feedback

The 02:45 timer is likewise invalid for five questions. Keep the image layout
idea but use the actual backend image/attribution; PHOTO: ARCHIVAL COLLECTION and
15th Century Folio are not verified provenance. Do not treat the depicted artwork
as a licensed production asset. Fit the image without losing identification
details, constrain its height responsively, and place the question before it
where that improves context. The Inspect button is not an approved separate
screen or gallery; start with a readable inline image and do not ship a dead
control. Any later zoom interaction needs an explicit design decision.

A skipped question has no selected answer. Mark Bosworth as Correct answer,
not a selected response, and use Skipped with a neutral icon. Show Skip question
only while answering. Replace the distant text-only action with a reachable
Continue button. Daily feedback stays compact; full explanation and provenance
are available in review. Image-loading failure must instead show retry/exit and
must never become this scored skip state.

### Daily Setup

Use this as the strongest setup reference. Preserve 5/10/20, five selected by
default, corresponding durations and official/practice status. Simplify the
framed explanation to a short unframed note. Reduce excessive blank space and
use Start challenge as the button label, since count/duration are already shown.
Keep the control stable and legible at large text sizes. Add the practice variant
with the saved official result available. During loading/image preparation show
a distinct disabled/preparing state; the timer starts only when play is ready.

### Quick Play Ordering Draft

Keep four position rows, drag handles, up/down alternatives and Submit order.
Use a positive remaining question time during editing; at 00:00 disable all
editing and submission and show timeout feedback. A draft order is not a
submitted wrong answer. Remove invented item subtitles, READY TO REVIEW and
verbose instructional blocks. Never ellipsize historical item text; allow it to
wrap and grow rows. Ensure each arrow has its own 48-pixel target and a useful
accessible label; disable moves beyond the ends. Reduce the oversized prompt
and make Submit order reachable without obscuring the fourth row. Preserve the
API's shuffled initial order and show the correct order only in feedback/review.

## Missing References And Delivery Recommendation

These eight exports do not include Quick Play setup, collection picker,
multiple-choice correct/incorrect feedback, true/false answering, image answering,
ordering submitted feedback, Results, full Review, or most error/preparation/save
states. They do not prove small-screen, large-text, or screen-reader behavior.

Proceed with MQ1/MQ2 without waiting for more artwork. Use the corrected shared
gameplay template in MQ3/MQ4's early harness and review one real phone rendering
before repeating it across all question types. Build missing states from the
approved written specifications and reused components. Results/review can receive
a focused visual review at MQ8; hub/setup at MQ9. Do not delay domain work for a
new full Stitch export, and do not postpone timer/outcome correctness until polish.

The current checkout has no lib/features/quiz or test/features/quiz directory;
MQ1 completion must be verified on the intended branch before advancing to MQ2.
This observation is a checkpoint note, not a permanent claim about task status.
