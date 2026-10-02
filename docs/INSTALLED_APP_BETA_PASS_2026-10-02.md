# Installed-App Beta Pass, 2026-10-02

Base: `origin/main` at `7764cee` (after mobile PR #13). Branch:
`claude/project-thread-nu6k8a`.

## How it was run

No phone or simulator was available, so this is a host-side pass, not native
evidence. A throwaway harness composed the real app the way `lib/main.dart`
does (real `AppRouter`, `ApiClient`, repositories, image cache, SQLite result
store through `sqflite_common_ffi`, notification pre-prompt store) against the
live CloudFront API, at a 390x844 phone viewport with the bundled fonts.
Firebase, push tokens and native permission dialogs were replaced by fakes.
"Restart" means a fresh object graph over the same on-disk database, image
cache and preference files. The harness was not committed.

Outages were simulated in the HTTP client: refused connections, a connection
that never answers, and every non-API (image) host unreachable.

## Results

| Path | Result |
| --- | --- |
| Cold start | PASS. Today rendered from the live API in about 1.6 s, 0.7 s on restart. |
| Today, Event Detail, image credit, sources | PASS. |
| Notifications denied (iOS-style) | PASS. Pre-prompt only at article end; after a denial it shows the device Settings message; the OS prompt is never shown unasked. |
| Daily Challenge, 5 questions, all question types | PASS. Results, Review and the Hub "Done" state were correct. |
| Saved results after restart | PASS. Hub showed the official 1 / 5 score and Review reopened from SQLite. |
| API refused | PASS. Today and Quiz show retry states; both recover after retry. |
| API hangs (no response) | FIXED. Quiz failed after 20 s, but Today and Event Detail waited forever on the loading skeleton. They now time out after 20 s and offer Try again. |
| Images unreachable | PASS with a decision for the owner (below). Today and Event Detail render without the picture; the Daily stops at "A picture couldn't load" with Retry and nothing scored. |
| Picture questions in Review | FIXED after owner request. Review only ever showed "Image unavailable in review." It now loads the image through the shared cache, also after a restart, and keeps that message only when the image cannot load. |
| App resumed on a later day | FIXED. Today and the Quiz Hub kept the previous day's content until the app was killed. They now reload when the app resumes on a new calendar day. |

Screenshots are in the project folder `screenshots/beta-pass-2026-10-02/`.

## Owner decisions surfaced

- An image outage blocks the whole Daily until images return (tested). Quick
  Play uses the same image preparation, so a round with a picture question
  should stop the same way (inferred, not run). Alternatives are skipping or swapping
  picture questions when their image cannot load; that changes official Daily
  scoring, so it was left as designed.
- The Quiz load-failure state is a plain message and button, while Today uses
  a card with an icon. Cosmetic only.

## Still unverified

Native install on iPhone and Android, real permission dialogs, Android 13
notification denial, VoiceOver/TalkBack, signed archives, and physical push.
