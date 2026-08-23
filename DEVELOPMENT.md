# Development

This repository contains the Flutter mobile app for On This Day.

## Prerequisites

- Flutter stable
- Dart from the Flutter SDK
- Xcode for iOS development on macOS
- Android Studio or Android SDK tooling for Android development

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

Start the empty application shell:

```sh
flutter run
```

Use a specific target when multiple devices are available:

```sh
flutter devices
flutter run -d <device-id>
```

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
