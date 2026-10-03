# Local Release-Readiness Audit

## Phase 0 Distribution Gates

The workplan's Phase 0 is a complete Today-to-tomorrow experience. The
September 15 evidence below is historical and does not certify these gates.
Record the device, build, date, and result for each check before changing a
gate from PENDING to PASS.

| Before inviting beta testers | Required evidence |
| --- | --- |
| Apple distribution | Owner-controlled signing/provisioning and successful Release archive. An owner-only TestFlight install may be used to verify production APNs before inviting beta testers. |
| Daily return | One scheduled remote notification for the featured event at the intended local date/time; permission accepted and denied paths; physical iPhone APNs/FCM receipt and warm/cold Event Detail deep links. Simulator/local push and token registration do not satisfy delivery. |
| Android | Signed release build, install on a physical Android phone, real FCM receipt and warm/cold Event Detail deep links; denial leaves the app usable. |
| Core phone journey | Today and Recent, featured image and full story, Daily and Quick Play, Results/Review, cold and warm image fetch, network loss, text scaling, and VoiceOver/TalkBack on their respective devices. |
| Privacy | Store disclosures and policy checked against actual SDK collection; existing Analytics/Crashlytics remain disabled until owner sign-off. |

The owner can authorize a narrower private distribution if a gate is pending,
but that exception must be recorded explicitly; it is not a TestFlight PASS.
Public v1 additionally requires the content, rights, operations, and native
release gates in `docs/PRODUCTION_LAUNCH_WORKPLAN.md`. Share cards come after
Phase 0 reliability; the native home-screen widget follows sharing. Neither
substitutes for the daily notification. Journey, reading quotas, and streaks
are not Phase 0 requirements.

## Phase 0 Verification Snapshot (2026-10-02)

Evidence from mobile `origin/main` at `fed132c`, checked in an isolated
worktree. This is not a distribution approval.

| Check | Result | Evidence or limit |
| --- | --- | --- |
| Flutter regression and analyzer | PASS | `flutter test --no-pub`: 529 tests; `flutter analyze --no-pub`: no issues. |
| Android debug packaging | PASS | `flutter build apk --debug --no-pub` produced an APK. |
| Android release guard | PASS | `flutter build appbundle --release --no-pub` failed clearly because owner-controlled `android/key.properties` is absent; no debug-signing fallback. This is not a signed bundle pass. |
| iOS Release compilation | PASS (unsigned) | `flutter build ios --release --no-codesign --no-pub` produced `Runner.app`. A signed archive and install remain pending. |
| iOS APNs configuration | PASS (configuration) | Xcode resolves `Runner.entitlements` with `development` for Debug and `RunnerRelease.entitlements` with `production` for Release. Delivery is unverified. |
| iOS simulator Today | PASS (smoke) | Debug app launched against CloudFront; October 2 Today returned HTTP 200 and the featured image framed correctly. No full native journey was exercised. |
| Production Quick Play API | PASS (API smoke) | A SHA-256-header POST for five questions returned HTTP 200 with all four question types. This is not a native quiz completion. |
| Android emulator Today | PENDING (environment) | App installed and showed Today behind a repeated Android System UI ANR; a clean emulator reboot reproduced it. Debug APK compilation passed, but interactive QA did not. |
| Physical phone, push, distribution | PENDING | No signed owner build, real APNs/FCM send, TestFlight install, Android release install, or native screen-reader pass was performed. |

Before inviting testers, use the owner's upload keystore and Apple
provisioning, verify release artifacts, then perform real-device push and
core-journey checks. An owner-only TestFlight build may establish production
APNs before the broader beta invitation. Keep telemetry disabled until
privacy disclosure and the existing event inventory are signed off.

## Current Beta Signing Gate (2026-10-02)

The September 15 observations below are historical, not current release state.
Release builds default to `https://d1v4ivrcr6v8za.cloudfront.net`; the
`ON_THIS_DAY_API_BASE_URL` dart-define can override it with an approved HTTPS
origin. Telemetry remains disabled pending privacy sign-off.

On the owner's Mac, create an upload keystore outside Git (the command prompts
for passwords), back it up, then place its actual values in ignored
`android/key.properties`:

```sh
mkdir -p "$HOME/.on-this-day"
keytool -genkeypair -v -keystore "$HOME/.on-this-day/upload-keystore.jks" \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

```properties
storeFile=/Users/<your-user>/.on-this-day/upload-keystore.jks
storePassword=<your-store-password>
keyAlias=upload
keyPassword=<your-key-password>
```

```sh
chmod 600 android/key.properties
flutter build appbundle --release
```

The Android release build fails if the signing file or keystore is missing; it
never uses the debug key. Debug builds do not need the file. For iOS, open
`ios/Runner.xcworkspace` in Xcode, select the owner's Apple Developer Team
and distribution provisioning profile, choose a generic iOS device, then use
Product > Archive. Debug/Profile target development APNs; Release targets
production APNs. A real signed archive, TestFlight upload, and physical-device
push test remain owner gates. See [DEVELOPMENT.md](../DEVELOPMENT.md) for details.

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
8. **Retention/operations:** decide on the existing minimal privacy-conscious
   product/crash telemetry before beta; collection stays off pending owner
   privacy sign-off. Share cards follow core reliability; the native widget
   follows sharing. Scheduled daily notifications and physical-device receipt
   are separate Phase 0 beta-rollout gates.

The stale content counts earlier in this file describe the verification run in
which they were observed. Refresh them through the coverage/status tooling
rather than editing them as if they were current production facts.
