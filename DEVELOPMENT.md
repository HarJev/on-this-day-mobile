# Development

This repository contains the Flutter mobile app for On This Day.

## Prerequisites

- Flutter stable
- Dart from the Flutter SDK
- Xcode for iOS development on macOS
- Android Studio or Android SDK tooling for Android development

The iOS deployment target is 15.0, as required by the current Firebase iOS SDK.

The project was bootstrapped with:

```sh
Flutter 3.41.2
Dart 3.11.0
```

Check your local toolchain with:

```sh
flutter --version
flutter doctor
```

## Setup

Install dependencies:

```sh
flutter pub get
```

## Run

Start the application:

```sh
flutter run
```

Use a specific target when multiple devices are available:

```sh
flutter devices
flutter run -d <device-id>
```

## Local Backend

By default the app calls the local backend at `http://127.0.0.1:3000`, which
works for the iOS simulator and local desktop targets when AWS SAM is running.
SAM must be listening on port `3000` unless you override the app base URL.

Run against local SAM from the iOS simulator:

```sh
flutter run --dart-define=ON_THIS_DAY_API_BASE_URL=http://127.0.0.1:3000
```

Run against local SAM from the Android emulator:

```sh
flutter run --dart-define=ON_THIS_DAY_API_BASE_URL=http://10.0.2.2:3000
```

For a physical iPhone, SAM must listen beyond loopback and the app must use the
Mac's LAN address. Do not use `127.0.0.1` from a phone:

```sh
# In /Users/jevaunharris/Workspace/on-this-day/on-this-day-backend
sam local start-api \
  --host 0.0.0.0 \
  --env-vars ./env.sam.compose-network.json \
  --warm-containers EAGER \
  --docker-network on-this-day-backend_default

# In this repository, with the iPhone and Mac on the same LAN
flutter run -d <iphone-device-id> \
  --dart-define=ON_THIS_DAY_API_BASE_URL=http://<mac-lan-ip>:3000
```

This validates local API reachability only. Remote FCM delivery still requires
the Apple Developer and APNs setup described below.

If SAM hangs while pulling the cached Java image, use the already downloaded
image explicitly and choose an unused port:

```sh
# In /Users/jevaunharris/Workspace/on-this-day/on-this-day-backend
sam local start-api \
  --skip-pull-image \
  --port 3001 \
  --env-vars ./env.sam.compose-network.json \
  --warm-containers LAZY \
  --docker-network on-this-day-backend_default

# Simulator or local desktop app
flutter run -d <device-id> \
  --dart-define=ON_THIS_DAY_API_BASE_URL=http://127.0.0.1:3001
```

This workaround avoids a SAM/Docker credential-helper stall observed during
local image preparation. The Java handler and database path were healthy once
the cached image was used.

The mobile app does not store backend secrets. The backend must already be
running with imported content before the Home and Event Detail screens can load
real data.

Notification device registration also uses the same backend base URL. When SAM
is running locally, the app registers FCM tokens with:

```text
POST /v1/devices
DELETE /v1/devices/{token}
```

Example registration request against local SAM:

```sh
curl -X POST http://127.0.0.1:3000/v1/devices \
  -H 'content-type: application/json' \
  -d '{
    "token": "example-fcm-token",
    "platform": "ios",
    "timezone": "America/Jamaica",
    "notificationPermissionStatus": "authorized"
  }'
```

For Android emulator testing, start the app with:

```sh
flutter run --dart-define=ON_THIS_DAY_API_BASE_URL=http://10.0.2.2:3000
```

After adding native plugins such as `flutter_timezone`, iOS needs a full app
stop and rebuild. A hot restart may keep running an older native plugin
registration.

## Production API URL

Release builds default to the deployed CloudFront API at
`https://d1v4ivrcr6v8za.cloudfront.net` (the backend `infra/prod`
`api_base_url` Terraform output). Do not use the raw Lambda function URL:
it requires IAM-signed origin requests. Debug builds still default to local SAM
at `http://127.0.0.1:3000`.

Build or run with the release default:

```sh
flutter build appbundle --release
flutter run --release -d <release-capable-device-id>
```

`ON_THIS_DAY_API_BASE_URL` still overrides the default in any build mode.
For example, to point a debug build at the deployed API:

```sh
flutter run -d <device-id> \
  --dart-define=ON_THIS_DAY_API_BASE_URL=https://d1v4ivrcr6v8za.cloudfront.net
```

For a release build against another approved HTTPS endpoint, pass the same
`--dart-define=ON_THIS_DAY_API_BASE_URL=https://<approved-api-host>` argument.
The release guard rejects HTTP and local/emulator hosts. The URL is public app
configuration, not a secret.

The shared API client sends the SHA-256 of the exact request body bytes on
POST and DELETE; local SAM accepts that header too. The deployed API currently
uses CloudFront `CachingDisabled`, so every GET reaches Lambda. Do not add
client behavior that assumes an edge-cached response.

The opt-in live smoke test renders Today and Quiz Hub using the real API,
then creates one five-question Quick Play round. It does not initialize
Firebase or register a device token:

```sh
flutter test integration_test/live_api_read_smoke_test.dart \
  -d <ios-simulator-id> \
  --dart-define=LIVE_API_READ_SMOKE=true \
  --dart-define=ON_THIS_DAY_API_BASE_URL=https://d1v4ivrcr6v8za.cloudfront.net
```

## Notifications

Firebase configuration is generated in `lib/firebase_options.dart`, with native
app config in `ios/Runner/GoogleService-Info.plist` and
`android/app/google-services.json`.

The v0.0.1 mobile registrations use Firebase project `on-this-day-98e6b` and
the matching native identifier `com.jevaunharris.onthisday` on both iOS and
Android. The older `com.example.*` Firebase registrations have intentionally
been left in place; do not delete them while existing builds may still refer to
them.

Regenerate client configuration through the authenticated CLIs rather than
editing app IDs or keys by hand:

```sh
firebase login
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
flutterfire configure \
  --project=on-this-day-98e6b \
  --android-package-name=com.jevaunharris.onthisday \
  --ios-bundle-id=com.jevaunharris.onthisday
```

Select the repository's already-configured platforms when prompted so web,
Windows, and macOS options remain available. If CocoaPods cannot find the
Firebase SDK version after a dependency update, run `pod repo update` once and
rebuild.

### Simulator notification loop

Debug builds include a notification icon in the Home header. Tapping it shows a
real local notification with the same JSON data contract used by Firebase:

```json
{"eventId":"battle-of-bosworth-field-1485"}
```

Tap the system notification to open that event through the normal
`/events/:eventId` route. The icon and action are absent from release builds.
The event ID can be changed for a debug run:

```sh
flutter run \
  --dart-define=ON_THIS_DAY_API_BASE_URL=http://127.0.0.1:3000 \
  --dart-define=ON_THIS_DAY_DEBUG_NOTIFICATION_EVENT_ID=battle-of-bosworth-field-1485
```

Local notification delivery validates simulator routing, payload parsing, and
backend detail loading. It does not validate APNs or remote FCM delivery.

For iPhone notification testing:

- Use a real iPhone for APNs/FCM validation. Do not rely on simulator push as
  proof that the production notification path works.
- In Xcode, confirm the Runner target has the Push Notifications capability.
- In Xcode, confirm Background Modes includes Remote notifications.
- Confirm the app bundle ID in Apple Developer, Firebase, and Xcode match.
- Use an APNs-capable paid Apple Developer team for the
  `com.jevaunharris.onthisday` App ID, then upload an APNs authentication key in
  Firebase before testing remote delivery.

After Firebase configuration or native plugin changes, fully stop the app and
rebuild it. Hot restart does not reload native Firebase/plugin registration.

The app registers captured FCM tokens with the backend. Scheduled delivery,
notification preferences, and disable-notification UI are intentionally
deferred.

## Verification

Format Dart files:

```sh
dart format .
```

Run static analysis:

```sh
flutter analyze
```

Run tests:

```sh
flutter test
```

Run the native SQLite integration test on an iOS simulator:

```sh
flutter devices
flutter test --no-pub integration_test/quiz_sqlite_result_store_test.dart \
  -d <ios-simulator-id>
```

This exercises the real iOS `sqflite` implementation, including schema
migration, idempotent receipts, rollback, corruption handling, and persisted
result rules. Run the same command with an Android device ID when an Android
emulator or device is available.

## Project Scope

The app implements the daily-history loop and the Quiz expansion, including
local result persistence. Product scope and architecture are documented in:

- `docs/PRODUCT.md`
- `docs/PRODUCT_DECISIONS.md`
- `docs/DESIGN.md`
- `docs/ARCHITECTURE.md`

For the latest observed Android/iOS checks, opt-in live quiz flow, image-host
limitations and remaining release gates, see
[Local release-readiness audit](docs/RELEASE_READINESS.md).

## Notification Verification Modes

Treat notification checks as separate claims:

| Mode | What it proves | Account requirement |
| --- | --- | --- |
| Debug local notification | System presentation, payload parsing, warm/cold navigation | None |
| iOS `simctl push` fixture | APNs-shaped simulator routing for the installed debug app | No paid Apple membership |
| Android emulator FCM | Firebase registration and remote FCM delivery | Firebase project configuration |
| Physical iOS FCM/APNs | Real production-style Apple delivery | Apple Developer/APNs credentials configured in Firebase |

The current debug local-notification path is the supported simulator fallback.
Adding a checked-in `simctl push` payload/command and moving the permission ask
behind an in-app explanation are pending launch-workplan tasks. Do not add a
production branch that silently substitutes local notifications when remote
delivery is unavailable. The app must remain fully readable when permission is
denied or credentials are absent.

Before claiming production daily notifications, verify the scheduled backend
job, timezone isolation, FCM response handling, and a real Android delivery.
Physical iOS delivery remains a separate manual gate until APNs ownership is
available.
