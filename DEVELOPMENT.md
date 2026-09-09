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

## Project Scope

This bootstrap intentionally does not implement product features. The v0.0.1
product scope and architecture are documented in:

- `docs/PRODUCT.md`
- `docs/PRODUCT_DECISIONS.md`
- `docs/DESIGN.md`
- `docs/ARCHITECTURE.md`
