# Closed Beta Native QA - 2026-09-30

Branch: `codex/closed-beta-native-qa` from mobile `main` (`ea6b887`). This is local QA evidence, not distribution approval. The backend repository and cloud resources were not changed.

## Environment

- Android: API 33 ARM64 emulator `emulator-5554`.
- iOS: iPhone 17 Pro simulator, iOS 26.2.
- API: local SAM on port 3000, backed by the existing healthy `on-this-day-postgres` container.
- Flutter 3.41.2 with bundled Dart 3.11.0. Homebrew `dart` resolves to 3.0.1.

## Results

| Gate | Status | Evidence |
| --- | --- | --- |
| Local content/API | PASS | SAM health 200. September 30 Today returned Botswana as featured and three additional events. Quick Play 20 returned owned CloudFront image URLs. |
| Android runner | PASS after alternate emulator boot; occasional runner instability remains | An API 33 ARM64 emulator completed the native SQLite five-test suite on retry. The first attempt stalled in Gradle/test startup. No app fatal exception was observed. |
| Android connected journey and images | PASS for test harness; native screenshots PENDING | Against local SAM and real owned images, the cold/warm cache test passed, and the live integration test completed Quick Play 20, Daily 5, Results, Review, and saved-result reopening. Production-install and visual checks remain pending. |
| iOS owned-image cache | PASS | `image_cache_live_test.dart` used a real API-selected CloudFront image. Cold fetch plus warm cache load completed with exactly one downloader call. |
| iOS live quiz flow | PASS | `quiz_live_api_test.dart` completed Quick Play 20 with all four question types and Daily 5 against local SAM and real images; Results, Review, official save, and reopening the isolated SQLite file passed. |
| Production app restart, denied permission, outages, related-history navigation | PENDING | The live test injects app dependencies and uses an isolated SQLite file. Existing widget tests cover several state paths; this pass did not exercise these paths on a production app install. |
| Normal-phone and larger-text visual review | PENDING | No new native screen captures were taken. Android never reached a reliable journey; iOS integration tests do not capture screenshots. The older ignored captures named in `CONNECTED_JOURNEY_NATIVE_REVIEW.md` are absent from this checkout. |
| VoiceOver/TalkBack | PENDING | No native screen-reader session was run. |
| Flutter regression and analysis | PASS | `flutter test --no-pub`: 505 tests passed. `flutter analyze --no-pub`: no issues. |
| Android release APK compilation | PASS | A release-only Gradle filter removes the dev-only `integration_test` registration for Java compilation and restores Flutter generated source afterward. `flutter build apk --release --no-pub` and a forced release Java recompile passed. The APK contains no `integration_test` package. This is not a signed distribution build. |
| Release configuration | PENDING owner inputs | Debug retains the local API default. Release startup rejects non-HTTPS or loopback API URLs. Gradle no longer selects debug signing for release; the store-bundle command requires private `android/key.properties` and a deployed HTTPS API URL. Neither input exists yet. |

## Fixes in this pass

- The Xcode FlutterFire build script now puts Flutter's Dart ahead of the older Homebrew Dart. `plutil -lint` passed, and both iOS integration builds then succeeded.
- The live quiz test waits for the rendered Start buttons instead of only the controller's Ready state. The prior iOS failure was a test-render race; the rerun passed.

## Reproduce

From the backend checkout, with the existing local PostgreSQL container available:

```sh
sam local start-api --skip-pull-image --port 3000 \
  --env-vars ./env.sam.compose-network.json \
  --warm-containers LAZY --docker-network on-this-day-backend_default
```

From the mobile checkout:

```sh
flutter test --no-pub integration_test/quiz_sqlite_result_store_test.dart -d emulator-5554
flutter test --no-pub integration_test/image_cache_live_test.dart \
  -d A4D10513-A9E7-4ED9-A7BB-D77E5D248F2A \
  --dart-define=LIVE_IMAGE_CACHE_TEST=true \
  --dart-define=ON_THIS_DAY_API_BASE_URL=http://127.0.0.1:3000
flutter test --no-pub integration_test/quiz_live_api_test.dart \
  -d A4D10513-A9E7-4ED9-A7BB-D77E5D248F2A \
  --dart-define=LIVE_API_TEST=true \
  --dart-define=ON_THIS_DAY_API_BASE_URL=http://127.0.0.1:3000
flutter build apk --release --no-pub
```

For an Android live API run, first use `adb reverse tcp:3000 tcp:3000` and set the app's API URL to `http://127.0.0.1:3000`. A Daily request can create an immutable assignment for the local date; do not reset it to rerun QA.

## Remaining owner actions

1. Use a physical Android device for release-like installation, outage/permission checks, screenshots, and saved-result restoration after an ordinary app restart. The emulator test harness has now covered the connected journey and image cold/warm path.
2. Supply a production HTTPS API endpoint and an owner-controlled Android upload keystore before building a distributable bundle. Follow the development guide and verify the signature.
3. The generated-registrant mismatch is fixed locally; recheck release and debug builds when upgrading Flutter.
4. Complete native larger-text and VoiceOver/TalkBack spot checks. Review any visual defects with a screenshot before changing layout.

No database or emulator app data was wiped. The local September 30 Daily assignment may have been created by the Hub's normal request and was left intact.

## Follow-up: Android packaging and release inputs

The release Java mismatch reproduced locally. The release compile filters
only Flutter generated integration-test registration; a finalizer restores
the file even after a forced compile. The APK contains no test plugin package.
A debug APK also builds. With no private signing file, a release APK built using a placeholder HTTPS API URL is unsigned, as confirmed by apksigner. The distribution script rejected missing API and signing inputs.

## Follow-up: Android native integration

A later cold boot of the alternate Pixel 6 API 33 emulator completed the
native SQLite test (5/5), real CloudFront image cold/warm test, and live SAM
Quick Play 20 plus Daily 5 journey through Results/Review and saved-result
reopening. SAM and emulator were stopped afterward. This does not prove
physical-device behavior or a production-install restart.
