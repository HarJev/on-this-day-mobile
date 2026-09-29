# Connected Quiz Journey: Native Review

Status: **COMPLETED with PENDING gates** (2026-09-29). iOS journey passes.
Defect D1 is fixed in
[HarJev/on-this-day-mobile#9](https://github.com/HarJev/on-this-day-mobile/pull/9)
(owner cleared mobile fixes after the review).
Android native evidence is blocked by the local emulators, and one enlarged-text
wrapping defect was found on Results. No application code was changed.

Report-only walkthrough of the merged connected-quiz feature. No application
code, content, Daily assignments, native configuration, dependencies or cloud
resources changed. Captures and logs are in the ignored
`build/connected-journey-review/` folder of this worktree (not committed).

## Environment

| Item | Value |
| --- | --- |
| Mobile | `main` 6cd4be8 (merge of #8, f6f5d7d), debug build, Flutter 3.41.2 |
| Legacy mobile (for old-result gate) | 7a50b00, the last `main` before the related-story feature |
| Backend | `main` dc329ad (merge of #17, f0ace9f) in a detached worktree, packaged with Corretto 21, `sam local start-api --warm-containers EAGER` on port 3000 |
| Database | Existing local Docker `on-this-day-postgres` (postgres:16-alpine), Flyway V1-V4 |
| iOS | iPhone 17 simulator, iOS 26.2 (main build). iPhone 17 Pro simulator, iOS 26.2 (legacy then main) |
| Android | Pixel 6 API 33 (existing, emulator-5554) and Pixel 3a API 33 (cold-booted by me) |
| Timezone | Device timezone America/Jamaica, backend date 2026-09-29 |

No local API was running at the start, so I started one from backend `main`.
The canonical backend checkout was on another worker's
`codex/connected-quiz-slate` branch (docs only on top of dc329ad). I left it
untouched and built from a detached worktree instead.

## Live data used

Read-only queries against the local database found:

- 37 relations covering 34 published questions and 31 events. No draft or
  retired links.
- Sep 29 featured story `cern-founded-1954` has linked questions.
  `GET /v1/events/cern-founded-1954` returned `hasRelatedQuizQuestions: true`.
- Existing Daily assignments (Sep 14-17 and Sep 26-28, selection v1) were not
  touched.
- **Side effect:** Sep 29 had no Daily assignment. The app's first normal Daily
  request created one (selection v2, 20 questions, created
  2026-09-29 12:55:31 UTC). This is normal app behaviour. Positions 1, 6, 14 and
  17 carry links: `cern-founded-1954`, `discovery-return-to-flight-1988`,
  `papua-new-guinea-independence-1975` and `botswana-independence-1966`. It is
  now immutable like any other assignment.

## Gate results

| # | Gate | iOS | Android |
| --- | --- | --- | --- |
| 1 | Today → current-day Event Detail → Quiz Hub, honest copy | PASS | PENDING |
| 2 | Daily → Results → Review → Related history → Event Detail → Back keeps result, disclosure and scroll | PASS | PENDING |
| 3 | Quick Play → Results → Review → Related history → non-current-day Event Detail → Back | PASS | PENDING |
| 4 | No related titles or answer clues before completion | PASS | PENDING |
| 5 | Old saved results and unlinked questions stay usable without placeholders | PASS | PARTIAL |
| 6 | Linked story load failure does not invalidate a saved result | PASS | PENDING |
| 7 | Normal phone and enlarged text: wrapping, reachable controls, safe areas | FAIL (one defect) | PENDING |
| 8 | Owned images prepared before timing; cached repeat load | PASS / PARTIAL | PENDING |
| 9 | No notification permission needed to enter the flow | PASS | PENDING |
| 10 | Screen reader (VoiceOver/TalkBack) semantics | PENDING | PENDING |

### 1. Today → Event Detail → Hub (iOS PASS)

The Sep 29 featured story (CERN, 1954) opens Event Detail. It ends with a 64px
row, "Explore today's quiz" / "Daily Challenge and Quick Play"
(`ios/02-event-detail-quiz-row.png`). This copy does not promise that a
particular story appears in a given Daily size. Tapping it pops to root and
selects the Quiz tab (`ios/03-after-quiz-row-tap.png`). Daily setup shows only
the count and time, with no story names (`ios/04-daily-setup.png`,
`ios/05-daily-ready.png`). Event Detail opened from Related history has no quiz
row (`ios/47-qp-related-event-detail-end.png`), because the route passes no
`isToday` argument. That matches the current-day-only rule.

### 2. Daily loop (iOS PASS)

I played an official 5-question Daily (3/5). Q1 is the linked CERN true/false.
Results (`ios/14-results.png`) → Review → I expanded Q1's "Related history",
which shows "1954 / CERN officially comes into existence"
(`ios/17-review-related-expanded.png`) → Event Detail loaded
(`ios/18-related-event-detail.png`) → Back. Review returned **byte-identical**
to the pre-navigation capture (`cmp` of `ios/17` and `ios/19`): same scroll
offset, disclosure still expanded, same result. Back again returned to Results
(`ios/20-results-after-back.png`). The saved snapshot contains
`relatedEvents` for the CERN question
(`official|2026-09-29|relatedEvents:[{"id":"cern-founded-1954",...}]`).
Results offers the related story only in its Worth revisiting card, so no card
appeared here because the first miss (Q2) is unlinked.

### 3. Quick Play loop (iOS PASS)

Practice replay: I missed linked Q1 on purpose, and the Worth revisiting card
shows a collapsed "Related history" (`ios/26`, `ios/27`). An untimed Mixed
Quick Play (5 questions) drew one linked question (Judiciary Act, 1789) and
four unlinked ones. Review → Related history → `judiciary-act-signed-1789`
Event Detail → Back returned to the same expanded disclosure and scroll
position (`ios/45`, `ios/46`, `ios/48`). Unlinked cards show no Related history
row or placeholder (`ios/44`).

### 4. No pre-completion leakage (iOS PASS)

Gameplay and feedback captures show only the prompt, options, explanation and
Sources after answering. No related title, year or link appears
(`ios/06`-`13`, `ios/24`, `ios/35`-`41`). Image questions keep "Image credit
after answering" until commit (`ios/38-qp-q3.png`).

### 5. Old results and unlinked questions (iOS PASS, Android PARTIAL)

On the iPhone 17 Pro simulator I installed legacy 7a50b00 against the same API
and saved an official Sep 29 Daily. The snapshot has no `relatedEvents` key,
although Q1 is the linked CERN question. I then installed `main` over it
without clearing data. The Hub shows the saved score
(`ios-legacy/06-upgraded-hub.png`), and Review renders Q1 with Sources only: no
Related history row, no placeholder, no error
(`ios-legacy/07-upgraded-legacy-review.png`).

On Android (Pixel 3a) the same legacy Daily was saved (`official`, no
`relatedEvents`), and the database survived the upgrade install. The emulator
then hit system-level ANRs before the Review screen could render, so the
Android visual check is PENDING.

### 6. Story-load failure (iOS PASS)

I stopped my local API, then tapped the Related history story from practice
Results. Event Detail showed the existing error card, "Could not load this
event." with "Try again" and "Back to Today", with no app crash (`ios/28`). The log recorded
`api_request_failure ... Connection refused`. Back returned to the unchanged
Results (`ios/29`). Both saved results remained in SQLite (`official`,
`practice`), and the Hub still showed today's saved score.

### 7. Normal and enlarged text (iOS FAIL: one defect)

At the default size, all screens fit with reachable controls and correct safe
areas. At iOS `accessibility-extra-large`:

- PASS: Review cards, the Related history disclosure and rows wrap cleanly
  with the chevron reachable (`ios/49`, `ios/50`). The Event Detail quiz row
  grows and stays tappable (`ios/57`). The Hub and Today wrap (`ios/53`,
  `ios/54`). The notification card wraps (`ios/55`).
- **FAIL (defect D1):** the Results stats row breaks words mid-word:
  "Answe/red", "Correc/t", "Unans/wered" (`ios/51-ax-qp-results.png`). The
  bottom action bar also takes about a third of the viewport, so the Worth
  revisiting card scrolls under it (`ios/52`). The row is
  `_Stats` in `lib/features/quiz/presentation/quiz_results_screen.dart`, three
  `Expanded` columns in a `Row`. It dates from the design pass (e4adeea), not
  from the connected feature, but it sits on this journey.

I restored the text size to `large` afterwards.

### 8. Images (iOS PASS / PARTIAL)

Daily and Quick Play waited on "Getting your challenge ready..." before
showing Start. Owned CloudFront images were on screen at the first frame of
each image question (Colosseum `ios/11`, Rosetta Stone `ios/38`), so no
answering time was spent loading. The shared disk cache holds 3 entries plus
an index under `Library/Caches/on-this-day-images/`. Cache hits and refetches
are logged only through `developer.log`, which `flutter run` stdout does not
show, so repeat-load behaviour was not directly observable (PARTIAL).
Full Review shows "Image unavailable in review." with collapsed credit. That
is existing behaviour, unchanged by this feature.

### 9. Notifications (iOS PASS)

Permission stayed `notDetermined` for the whole run. No OS prompt appeared
entering Event Detail, Hub, Daily, Quick Play, Results or Review. The in-app
"A daily note from history" card appears only at the end of Event Detail, and
I never tapped it. Permission policy was not changed.

### 10. Screen readers (PENDING)

I did not run VoiceOver or TalkBack. Semantics labels were read from code only:
the quiz row reads "Explore today's quiz. Daily Challenge and Quick Play". This
is not native evidence.

## Android blocker

- The existing Pixel 6 API 33 emulator (emulator-5554, not started by me)
  showed repeated "System UI isn't responding" and "Process system isn't
  responding" dialogs that did not clear. Captures are in
  `android/pixel6-api33-wedged/`. I installed the legacy build on it while
  trying (debug install, app data had no saved results before).
- I cold-booted a Pixel 3a API 33 (emulator-5556). The legacy build ran and
  saved a Daily, but the emulator was slow enough that the 2-minute Daily clock
  expired after Q1. That is correct wall-clock behaviour, not an app defect.
  After the main-build install, the app and then System UI hit ANRs and
  `input` service calls failed. Host load average was about 30-44 during this
  run (other sessions active).
- The featured image did not render on the fresh Pixel 3a boot, while the
  network was still settling (status bar showed no validated connection at
  first). This is inconclusive, not a finding.

I stopped the Pixel 3a emulator. Android gates need a rerun on a quieter host
or a physical device.

## Findings and fixes

**D1. Results stats labels break mid-word at large text sizes.** On iOS
accessibility-extra-large, "Answered", "Correct" and "Unanswered" split across
lines. Proposed scoped fix: in `_Stats`, switch from a three-column `Row` to a
vertical list when the labels no longer fit, and add a widget test at 2.0x. No
copy or design change.

**Fixed** in PR #9 (`codex/results-stats-large-text`, from `main` e4d31ea).
`_Stats` measures "Unanswered" with the current text scaler and stacks the
counts when it doesn't fit its column. The new 1x/2x test fails at 2x without
the fix. The full suite passes (505 tests), the analyzer reports no issues,
and `git diff --check` is clean. On the iPhone 17 simulator the labels are
whole and stacked at accessibility-extra-large (`ios/60-fix-ax-results.png`),
and the default size is unchanged (`ios/61-fix-normal-results.png`).

Owner merges after the review (e4d31ea mobile, 2105fc4 backend) change no
runtime code: the mobile merge is a handoff doc, and the backend merge is
Oct 2-8 content plus one test tweak. No backend issues were found, so no
backend fix is proposed.

Untested observation: on that error card, reached from Quiz Results, the
secondary button reads "Back to Today". I used the header Back arrow, which
returns to Results, and did not tap that button.

Not a defect, noted for the owner: the Hub result strip draws a timed-out
question with the same copper cross as a wrong answer
(`ios-legacy/06-upgraded-hub.png`), while Review labels it "Timed out".

## Reproduce

1. Backend: create a worktree at `main`, run
   `JAVA_HOME=$(/usr/libexec/java_home -v 21) mvn -B -DskipTests package`, then
   `sam build`, then
   `sam local start-api --env-vars ./env.sam.compose-network.json --warm-containers EAGER --docker-network on-this-day-backend_default --port 3000`.
2. Mobile: run
   `flutter run -d <sim> --dart-define=ON_THIS_DAY_API_BASE_URL=http://127.0.0.1:3000`.
   For Android, first run `adb reverse tcp:3000 tcp:3000`.
3. Today → CERN → end of story → "Explore today's quiz" → Daily 5 → play →
   Review answers → Q1 Related history → story → Back → Back.
4. Old results: run step 2 at 7a50b00, complete a Daily, then run step 2 at
   `main` on the same device without uninstalling, and open Review answers.
5. Failure: stop the API, open a Related history story from Results, then press
   Back.
6. Enlarged text: run
   `xcrun simctl ui <udid> content_size accessibility-extra-large` and reopen
   Results and Review.

## Remaining

- Android gates 1-9 native rerun.
- VoiceOver/TalkBack pass for Review Related history and the Event Detail quiz
  row.
- Review and merge PR #9 (D1).

## Housekeeping

I stopped every process I started: both iOS `flutter run` sessions, the
legacy/main Android runs, SAM local and the Pixel 3a emulator. The Docker
database and the Pixel 6 emulator were already running and were left running.
Both iOS simulators now hold completed Sep 29 results. I removed my temporary
worktrees after committing.
