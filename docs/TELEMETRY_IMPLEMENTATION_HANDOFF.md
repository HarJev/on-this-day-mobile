# Telemetry implementation handoff

Updated: 2026-10-01. Branch: `codex/mobile-push-readiness`. Work is uncommitted;
preserve the pre-existing dirty QA/native changes. This note is for a future
agent to resume without redoing the investigation.

## Request and decision

Add Firebase Analytics and Crashlytics where useful, research other relevant
SDKs, and continue launch readiness. Owner decision: **collection stays off
until privacy disclosure and event inventory are signed off**. No Firebase
console changes, deployment, production collection, commit, or push requested.

## Implemented

- Added `firebase_analytics` and `firebase_crashlytics` packages and ran
  `flutterfire configure` for the existing Android/iOS Firebase app IDs.
- Added `lib/core/telemetry/app_telemetry.dart` and
  `telemetry_route_observer.dart`; events use fixed names/parameter values,
  with no IDs, answers, URLs, tokens, dates, or free-form messages.
- Added native collection-off settings to Android manifest and iOS Info.plist.
  Dart requires both release mode and
  `ON_THIS_DAY_TELEMETRY_ENABLED=true` to enable collection.
- Wired Today/Recent, root tabs/routes, quiz start/completion/image-prep
  failures, and deferred notification-prompt decisions.
- Added focused route/prompt tests and `docs/TELEMETRY.md` with event inventory,
  rollout switch, privacy gate, and SDK recommendations. Owner checklist links
  to the document.
- FlutterFire added an iOS Crashlytics symbol-upload phase; its PATH was
  corrected to prioritize Flutter's bundled Dart.
- Android native integration was separately completed earlier this turn on
  an API 33 emulator: SQLite 5/5, CloudFront cold/warm image, and live SAM
  Quick Play 20/Daily 5 through saved Results/Review. QA report updated.
- Backend `main` includes scheduled FCM delivery (`def3805`) with notification
  title/body and `data.eventId`. The mobile API registration contract matches.
- Mobile push startup now tolerates an unavailable initial FCM message or
  listener setup; foreground messages with complete content use the local
  notification gateway after permission is allowed. Existing cold/background
  taps and token registration remain in place.
- Android Google Services Gradle plugin was raised to 4.5.0 because Crashlytics
  plugin v3 requires at least 4.4.1. iOS Podfile.lock now records the added
  Analytics and Crashlytics pods.

## Verification so far

- Focused telemetry/notification tests: PASS (27 tests).
- Full `flutter test --no-pub`: PASS (510 tests after push changes).
- `flutter analyze --no-pub`: PASS.
- Formatting with Flutter's bundled Dart: PASS. The Homebrew `dart` is old;
  use `/Users/jevaunharris/flutter/bin/dart`.
- Android debug APK build: PASS (`flutter build apk --debug --no-pub`; Gradle
  assembled `build/app/outputs/flutter-apk/app-debug.apk`).
- Android release APK compilation: PASS with a placeholder HTTPS API URL and
  telemetry flag omitted. This APK is not signed for distribution.
- iOS Simulator targeted `flutter run --debug --no-resident --no-pub -d
  A4D10513-A9E7-4ED9-A7BB-D77E5D248F2A`: PASS without Apple signing. The app
  launched, displayed the Today offline retry state with local SAM stopped,
  and exposed the debug bell. A screenshot was inspected. Generic
  `flutter build ios --simulator` hit a Flutter/Xcode universal-architecture
  thinning error (`lipo -verify_arch arm64 x86_64`); targeted run succeeded.
- Focused notification tests after push changes: PASS (37 tests).
- `plutil -lint ios/Runner/Info.plist`: PASS.
- `git diff --check`: PASS.
- Firebase project/app IDs in `lib/firebase_options.dart` were unchanged;
  the FlutterFire default platform mapping was aligned to the existing app IDs.

## Remaining checks and owner steps

1. Keep telemetry collection OFF until the owner approves the privacy
   disclosure and event inventory. No console ingestion or crash upload has
   been verified.
2. When the Apple Developer account is available, configure the production
   App ID with Push Notifications, provisioning/profile, and APNs authentication
   key in Firebase; test physical iOS delivery in foreground, background, and
   cold launch. No app code should assume this has already happened.
3. Deploy the backend scheduled sender only through the separately approved
   deployment plan; verify a real Android FCM delivery and scheduler behavior.
4. Supply the production HTTPS API URL and owner-controlled signing for store
   builds. iOS/Android release distribution remains an owner gate.

## Existing worktree caveat

At turn start, `DEVELOPMENT.md`, Android Gradle release work,
`integration_test/quiz_live_api_test.dart`, iOS project PATH work,
`lib/core/config/app_config.dart`, QA checklist/report, and `scripts/` were
already dirty. Do not discard or stage them wholesale. This task added its
own telemetry files and touched native configs/routing/notification code.
