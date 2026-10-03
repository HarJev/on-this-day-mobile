# Phase 0 Live App Audit, 2026-10-02

Base: mobile main at `aff83da`, plus an expanded opt-in live integration
harness. API: `https://d1v4ivrcr6v8za.cloudfront.net`. The test used
`America/Jamaica`; the API resolved October 2. No production device tokens
were registered, and no production result database was changed.

## Native Walkthrough

| Platform | Result | Evidence |
| --- | --- | --- |
| iOS 26.2, iPhone 17 Pro simulator | PASS | Today and Recent returned 200; the featured Gandhi image rendered, pull-to-refresh reloaded Today, the featured story opened with sources and image, a Recent story opened with sources, Quick Play 20 exercised all four types with real images, Daily 5 completed, Results/Review opened, and the official result reopened from isolated SQLite. |
| Android 13, Pixel 6 ARM64 emulator | PASS | The same live walkthrough completed with real image fetches and isolated SQLite save/reopen. Emulator RAM was raised to 3072 MiB after an earlier 1536 MiB System UI ANR. |
| Actual app visual check | PASS (limited) | Debug builds launched on both simulators against CloudFront. Today's featured portrait, card, story link and root navigation were visible without clipping. Captures: `/private/tmp/on-this-day-live-ios-today-2026-10-02.png` and `/private/tmp/on-this-day-live-android-today-2026-10-02.png`. |

Command used for each simulator:

```sh
flutter test --no-pub integration_test/quiz_live_api_test.dart \
  -d <simulator-or-emulator-id> \
  --dart-define=LIVE_API_TEST=true \
  --dart-define=ON_THIS_DAY_API_BASE_URL=https://d1v4ivrcr6v8za.cloudfront.net
```

The harness uses the production router, repositories, image downloader/cache,
quiz preparation and SQLite store, but an isolated temporary database and
image directory. It does not initialize Firebase or request permission.
The walkthrough is date/content-dependent and intentionally opt-in. The
assertions were expanded to cover Today and Recent; test-only scrolling/tap
timing was adjusted for long articles and below-the-fold actions.

## Remaining Gates

These PASS results do not certify distribution. Still PENDING: signed Android
release installation, Apple provisioning and TestFlight, physical-phone
performance and network recovery, real scheduled APNs/FCM delivery and deep
links, owner privacy/store disclosures, and a physical-device core-journey
check. The owner moved the dedicated manual VoiceOver/TalkBack pass to Phase 1;
basic semantic-label and text-scaling quality remain Phase 0 expectations.
No production UI defect was identified in this bounded native walkthrough.
