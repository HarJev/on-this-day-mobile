# Claude Context - On This Day Mobile

## Required Reading

Read `AGENTS.md` first. Then read the documents relevant to the task:

- `docs/PRODUCT.md`
- `docs/PRODUCT_DECISIONS.md`
- `docs/DESIGN.md`
- `docs/ARCHITECTURE.md`
- `docs/design/QUIZ_SCREEN_REVIEW.md` for Quiz UI work
- `docs/PRODUCTION_LAUNCH_WORKPLAN.md` for launch work
- `implementation_plan.md` and `quiz_implementation_plan.md` for history
- `../PROPOSED_CHANGES.md` for current priorities and screenshot evidence
- `../CLAUDE.md` for shared workflow rules

Do not duplicate or replace those documents here. If they disagree, report the
conflict before changing behavior.

## Current Reality

This is a Flutter application with an intentional retained Today/Quiz root
shell. Quiz is implemented, not speculative. It includes:

- catalog, Daily Challenge, and Quick Play;
- multiple choice, true/false, image identification, and ordering;
- deterministic timing and lifecycle reconciliation;
- local SQLite result persistence;
- Results and full Review;
- bounded image preparation and a shared disk byte cache;
- Firebase Messaging token registration and notification deep links.

Some older `AGENTS.md` language describes Quiz or bottom navigation as out of
scope. Newer product decisions and the current application supersede those
specific stale statements. Preserve the implemented Today/Quiz experience.

## Architecture

Keep the established boundaries:

- `lib/core/` - app-wide API, configuration, images, navigation, notifications.
- `lib/features/on_this_day/` - Today and Event Detail.
- `lib/features/quiz/domain/` - immutable models and pure grading.
- `lib/features/quiz/data/` - API and SQLite implementations.
- `lib/features/quiz/application/` - app-scoped coordination.
- `lib/features/quiz/presentation/` - controllers, session timing, and UI.

Widgets render state and forward actions. They must not parse API responses,
perform direct HTTP calls, grade answers, or own timing rules.

## Design And UX

Follow `docs/DESIGN.md` and the reviewed screenshots. Prefer the written
corrections when screenshots conflict with approved behavior.

Keep the app editorial, compact, and calm:

- warm paper background, soft ivory surfaces, cobalt and muted copper accents;
- readable serif hierarchy with restrained sans-serif support;
- zero unintended letter spacing;
- accessible text, semantics, controls, contrast, and safe areas;
- quiz prompt, relevant image, options, and primary action visible with minimal
  scrolling on normal phones;
- no technical backend/Firebase language in product copy.

Do not expose answer-bearing image attribution, artwork titles, filenames,
source names, URLs, or other clues while an image question is still answerable.
Neutral alt text remains available to accessibility services. Full provenance
must remain available after submission and in Review.

## Firebase And Native Files

The production package identity is `com.jevaunharris.onthisday`.

- Do not hand-edit Firebase app IDs, generated credentials, signing identities,
  or provisioning data.
- Do not delete legacy Firebase clients merely because they are present.
- Simulator/local notifications and real APNs/FCM delivery are distinct
  verification modes.
- Physical iOS push requires Apple provisioning.
- Preserve iOS 15 deployment-target handling in the Podfile.
- Never commit secrets or private signing material.

## Verification

For Dart changes:

1. Run `dart format` on edited files.
2. Run focused tests.
3. Run one full `flutter test` regression pass for behavior changes.
4. Run `flutter analyze`.
5. Run `git diff --check`.

For visual changes, capture and inspect representative normal-phone states.
Only claim native accessibility or physical-device behavior when actually
tested.

Use fake repositories/services in normal tests. Live backend/device checks
belong in explicit integration verification.

## Git

Use a dedicated `codex/` or claude/branch or the worktree named by the task. Preserve
unrelated changes. Commit and push verified approved work, but do not merge or
open a PR unless requested.
