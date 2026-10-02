# Release Signing and APNs Handoff

Date: 2026-10-02. Branch: `claude/release-signing-apns`, based on
`origin/main` at `41226dd`. The owner approved this beta-readiness task.
Do not merge the branch or push to main.

## Scope

- Debug/Profile iOS APNs remains development; Release becomes production.
- Android release bundle must require owner-controlled signing material and
  never fall back to the debug key.
- Document owner keystore and iOS archive steps. Keep telemetry disabled and
  the CloudFront release API default unchanged.
- Run focused/full Flutter checks, analyzer, unsigned iOS Release build,
  build-setting/entitlement inspection, and missing-key Android failure check.
- Commit, push the branch, and open one PR against main.

## Verified Implementation

- Debug/Profile retain development APNs; Release uses the production
  entitlement. `xcodebuild -showBuildSettings` confirmed all three paths and
  the unchanged iOS 15 deployment target. Both plist files pass `plutil -lint`.
- The unsigned generic-device iOS Release build passed after `pod install`
  restored the generated Pods manifest. The resulting app is deliberately
  unsigned, so `codesign` cannot inspect embedded entitlements; a signed
  archive and physical-device APNs delivery remain owner-only gates.
- `flutter build appbundle --release` without `android/key.properties`
  failed immediately with the intended clear signing message. No keystore or
  passwords were created. `flutter build apk --debug` passed without it.
- Focused app config tests: 6 passed. Full `flutter test`: 522 passed.
  `flutter analyze`: no issues. `git diff --check`: clean.
- No Dart files changed, so Dart formatting is not applicable. No telemetry,
  Firebase app IDs, local API behavior, or tracked credentials changed.

## PR

Committed as `5e20cb6` and opened
[mobile PR #13](https://github.com/HarJev/on-this-day-mobile/pull/13)
against main. Do not merge until owner review.

## Owner-Only Gates

- Generate and securely back up the Android upload keystore/passwords.
- Configure Apple Developer Team, distribution signing and provisioning.
- Archive/upload through Xcode and verify physical-device remote push.
- Approve privacy disclosure before enabling telemetry.

The one-time continuation was deleted after the PR opened.
