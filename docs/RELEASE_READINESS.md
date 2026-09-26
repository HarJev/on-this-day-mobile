# Local Release-Readiness Audit

Date: 2026-09-15. Branch: `codex/mobile-visual-polish`.
This records observed evidence, not a production release approval.
No physical-device checks, deployment, commits or pushes were performed.

## Verified

| Area | Result |
| --- | --- |
| Mobile regression suite | 332 tests passed after final UI changes |
| Static analysis | `flutter analyze`: no issues |
| Formatting / whitespace | Edited Dart files formatted; `git diff --check` clean |
| Android native SQLite | All 5 integration tests passed on API 33 ARM64 emulator |
| iOS native SQLite | All 5 integration tests passed on iPhone 17 Pro simulator |
| Android native app | Built and installed; Today fetched live September 15 content |
| Android Firebase | Firebase initialized; notification permission authorized; real FCM token obtained; local `POST /v1/devices` returned 200 |
| Android quiz flow | Live SAM catalog, Quick Play 20, all four types, Daily 5, Results, Review, SQLite save and reopen passed with explicit image fixtures |
| iOS quiz flow | Same live API / native SQLite flow passed with explicit image fixtures |
| Visual review | Widget-rendered Hub, setup, ready, image, ordering, Results and large-text Review captures inspected |

The live quiz flow uses production repositories, route ownership, decoding,
grading, completion coordination and SQLite. Its isolated temporary database
does not replace personal quiz history. The fixture-image mode only substitutes
the external download step and must not be reported as real-image delivery proof.
Native flows passed before the final ready-button placement adjustment; the final
placement and image-failure labels were covered by the subsequent widget suite.

## Fixes In This Pass

- Dismissing the collection sheet no longer silently selects Mixed. Explicit
  Mixed selection remains supported; regression coverage exercises both paths.
- Android and iOS launcher display names now read `On This Day`.
- Optional Today/Event Detail images collapse cleanly on failed loading/decoding,
  without a broken image block or orphaned image spacing.
- Ready/Retry actions sit directly below session details rather than at the
  bottom of an otherwise empty screen. Scroll and safe-area access remain at
  large text sizes; active gameplay keeps its bottom controls.
- Failed preparation no longer claims `Images ready`.
- Image HTTP failures preserve host/status diagnostics without logging tokens,
  full query strings or credentials.

Earlier visual-polish and native SQLite changes were preserved. Firebase generated
configuration was not regenerated: the Android build and successful registration
demonstrate selection of the existing `com.jevaunharris.onthisday` client. The
legacy client entry remains untouched.

## Remaining Release Gates

1. **Image delivery:** the real-image native test failed because
   `upload.wikimedia.org` returned HTTP 429. Some direct downloads succeeded,
   then later requests were rate limited. Valid links and smaller files do not
   guarantee availability. Preparation correctly fails before timing/scoring.
   Before release, arrange reliable licensed image delivery (retaining source,
   creator, attribution and license metadata), then rerun without fixture mode.
   Do not bypass provider rate limits or silently substitute quiz images.
2. **Native visual/accessibility pass:** the Mac locked during this run, preventing
   final interactive screenshots and VoiceOver/TalkBack review. Automated widget
   captures and semantics checks do not certify native speech or physical safe areas.
3. **Signing and environment:** Android release currently uses debug signing;
   configure an owner-controlled release key before distribution. The API default
   remains local-only. A production HTTPS endpoint, release build configuration,
   and iOS distribution signing remain future release work. No credentials created.
4. **Remote push:** Android token capture/registration passed, not end-to-end FCM
   delivery. No real cloud push was sent. iOS APNs/provisioning and physical push
   remain outside this audit.
5. **Content depth:** September 16-30 now have two reviewed events per date, not
   six additional events. September 1-14 remain unfilled. Quiz bank is 96, not the
   eventual 240-question target. See backend `docs/SEPTEMBER_CONTENT_REVIEW.md`.

## Reproduce The Live Flow

With PostgreSQL and imported content available, start SAM from the backend:

```sh
sam local start-api --skip-pull-image --port 3000 \
  --env-vars ./env.sam.compose-network.json \
  --warm-containers LAZY --docker-network on-this-day-backend_default
```

Then from the mobile repository (replace the device ID with an available target):

```sh
flutter test --no-pub integration_test/quiz_live_api_test.dart \
  -d emulator-5554 --dart-define=LIVE_API_TEST=true \
  --dart-define=ON_THIS_DAY_API_BASE_URL=http://10.0.2.2:3000
```

For iOS simulator use `http://127.0.0.1:3000`. For isolated API/SQLite diagnosis
when the image host is unavailable, explicitly add
`--dart-define=LIVE_API_FIXTURE_IMAGES=true`. This is a test-only flag, not an app
fallback or a shipping setting. Without `LIVE_API_TEST=true` the opt-in suite skips.

Local generated captures: `/tmp/on-this-day-final-qa/` (temporary, not committed).
Final complete test log: `/tmp/on-this-day-final-qa/mobile-tests.log`.

Normal Android/iOS simulator debug builds were rebuilt after the checks to
replace the integration-test entry points. SAM was stopped after verification;
PostgreSQL and imported content were preserved. Start SAM before using the apps.

## Accepted Post-Audit Gates

The following findings are accepted work, not completed release evidence:

1. **Image redirects:** cache misses must safely handle bounded HTTPS redirects,
   and every published quiz image must pass a real first-fetch check. A warm
   cache does not satisfy this gate.
2. **Permission timing:** notification permission must follow rendered product
   value and an in-app explanation. Declining it must leave all content usable.
3. **Connected Daily:** future Daily generation should include an explicitly
   linked featured-event question when one is available while preserving stable
   assignments and balanced fallback.
4. **Recent recovery:** provide a seven-calendar-day window without introducing
   arbitrary archive browsing.
5. **Notification delivery:** add the scheduled backend job and isolate missing
   content/timezone failures. Debug local notification delivery is not a remote
   push pass.
6. **Editorial quality:** audit existing distractors, correct-answer position
   distribution, difficulty, related-event metadata, and featured-image review.
7. **Content state:** prove agreement between approved canonical content and the
   target database through counts and fingerprints.
8. **Retention/operations:** add minimal privacy-conscious product/crash
   telemetry before beta; widget and share cards follow core reliability.

The stale content counts earlier in this file describe the verification run in
which they were observed. Refresh them through the coverage/status tooling
rather than editing them as if they were current production facts.
