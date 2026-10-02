# Mobile Telemetry

Firebase Analytics and Crashlytics are integrated but collection is **off by
default** on Android and iOS, including before Dart starts. Debug and profile
builds cannot enable it. Do not enable production collection until the owner
approves the privacy disclosure and this event inventory.

## Approved-code event inventory (not yet approved for collection)

| Event | Parameters | Purpose |
| --- | --- | --- |
| `history_screen_viewed` | Fixed screen enum only | Find navigation drop-off. |
| `history_today_loaded` | None | Measure successful Today loads. |
| `history_recent_opened` | None | Measure Recent use. |
| `quiz_started`, `quiz_completed` | `mode` (`daily` or `quick_play`), `question_count` | Understand completion by mode and length. |
| `quiz_image_preparation_failed` | Fixed failure category | Diagnose image reliability. |
| `history_notification_prompt` | Fixed outcome | Evaluate the deferred permission offer. |

No event sends an event/question ID, answer, date, location, notification
token, source URL, image URL, query string, or free-form error message.
Crashlytics may capture exception stacks and platform/device diagnostics when
enabled; disclose this separately from the custom Analytics event inventory.
Do not add user identifiers or raw exception messages to custom keys.

## Enabling after owner sign-off

The native defaults in `AndroidManifest.xml` and `Info.plist` stay off. After
the privacy/store disclosures and collection decision are approved, make a
release build with:

```sh
--dart-define=ON_THIS_DAY_TELEMETRY_ENABLED=true
```

The app explicitly enables both SDKs at startup only in release mode with
that flag. A release without the flag keeps them off. Verify collection in
Firebase DebugView/Crashlytics using a consented test device before shipping,
and check that the iOS Firebase project's Analytics configuration permits
collection; its current `GoogleService-Info.plist` says
`IS_ANALYTICS_ENABLED=false`. Do not hand-edit Firebase app identifiers or
generated credentials. If configuration changes are needed, use FlutterFire
and the Firebase console with the owner account.

Firebase Analytics, Crashlytics, Performance Monitoring and App Distribution
are listed as no-cost Firebase products, though other linked infrastructure
may incur charges. Performance Monitoring is deferred: its automatic network
and startup collection adds privacy scope without addressing an established
launch blocker. App Distribution is useful for beta builds once signing is in
place; it needs no runtime SDK. App Check is also deferred: this app uses a
custom backend, so adding the client SDK alone would not protect API routes;
the backend would also need token verification and rollout planning.

Official references: [Firebase pricing](https://firebase.google.com/pricing),
[Analytics collection controls](https://firebase.google.com/docs/analytics/configure-data-collection),
[Crashlytics collection controls](https://firebase.google.com/docs/crashlytics/customize-crash-reports),
[Performance Monitoring](https://firebase.google.com/docs/perf-mon/flutter/get-started),
[App Check for custom backends](https://firebase.google.com/docs/app-check/custom-resource-backend).
