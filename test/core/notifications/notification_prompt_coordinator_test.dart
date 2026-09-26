import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_store.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';

import 'support/notification_prompt_fakes.dart';

void main() {
  group('NotificationPromptCoordinator.shouldOffer', () {
    final cases = <(NotificationPermissionStatus, bool, bool)>[
      // (status, deniedMayBeUnasked [Android], expected)
      (NotificationPermissionStatus.notDetermined, false, true),
      (NotificationPermissionStatus.notDetermined, true, true),
      (NotificationPermissionStatus.authorized, false, false),
      (NotificationPermissionStatus.provisional, false, false),
      (NotificationPermissionStatus.denied, false, false),
      (NotificationPermissionStatus.denied, true, true),
      (NotificationPermissionStatus.permanentlyDenied, false, false),
      (NotificationPermissionStatus.permanentlyDenied, true, false),
    ];
    for (final (status, deniedMayBeUnasked, expected) in cases) {
      test(
        '$status (deniedMayBeUnasked: $deniedMayBeUnasked) -> $expected',
        () async {
          final permissions = FakePermissionGateway(status: status);
          final coordinator = promptCoordinator(
            permissions: permissions,
            deniedMayBeUnasked: deniedMayBeUnasked,
          );

          expect(await coordinator.shouldOffer(), expected);
          expect(permissions.requestCount, 0);
        },
      );
    }

    for (final decision in NotificationPromptDecision.values) {
      test('is false once the user has $decision', () async {
        final permissions = FakePermissionGateway();
        final coordinator = promptCoordinator(
          permissions: permissions,
          store: InMemoryPromptStore(decision: decision),
        );

        expect(await coordinator.shouldOffer(), isFalse);
        expect(permissions.statusReadCount, 0);
      });
    }

    test('is false when the saved decision cannot be read', () async {
      final coordinator = promptCoordinator(
        store: InMemoryPromptStore(readError: Exception('disk')),
      );

      expect(await coordinator.shouldOffer(), isFalse);
    });

    test('is false when the permission status cannot be read', () async {
      final coordinator = promptCoordinator(
        permissions: FakePermissionGateway(statusError: Exception('channel')),
      );

      expect(await coordinator.shouldOffer(), isFalse);
    });
  });

  group('NotificationPromptCoordinator.enable', () {
    test(
      'authorized: records the decision and registers in the background',
      () async {
        final store = InMemoryPromptStore();
        final registration = RecordingRegistration()
          ..pending = Completer<void>();
        final permissions = FakePermissionGateway(
          requestResult: NotificationPermissionStatus.authorized,
        );
        final coordinator = promptCoordinator(
          permissions: permissions,
          store: store,
          registration: registration,
        );

        // Completes even though registration is still pending.
        final outcome = await coordinator.enable();

        expect(outcome, NotificationPromptOutcome.enabled);
        expect(permissions.requestCount, 1);
        expect(store.writes, [NotificationPromptDecision.requested]);
        expect(registration.calls, [NotificationPermissionStatus.authorized]);
        registration.pending!.complete();
      },
    );

    test('provisional counts as enabled and registers', () async {
      final registration = RecordingRegistration();
      final coordinator = promptCoordinator(
        permissions: FakePermissionGateway(
          requestResult: NotificationPermissionStatus.provisional,
        ),
        registration: registration,
      );

      expect(await coordinator.enable(), NotificationPromptOutcome.enabled);
      await Future<void>.delayed(Duration.zero);
      expect(registration.calls, [NotificationPermissionStatus.provisional]);
    });

    for (final status in [
      NotificationPermissionStatus.denied,
      NotificationPermissionStatus.permanentlyDenied,
    ]) {
      test('$status is reported as blocked without registration', () async {
        final store = InMemoryPromptStore();
        final registration = RecordingRegistration();
        final coordinator = promptCoordinator(
          permissions: FakePermissionGateway(requestResult: status),
          store: store,
          registration: registration,
        );

        expect(await coordinator.enable(), NotificationPromptOutcome.blocked);
        expect(store.writes, [NotificationPromptDecision.requested]);
        expect(registration.calls, isEmpty);
      });
    }

    test('an undecided system prompt is reported honestly', () async {
      final coordinator = promptCoordinator(
        permissions: FakePermissionGateway(
          requestResult: NotificationPermissionStatus.notDetermined,
        ),
      );

      expect(await coordinator.enable(), NotificationPromptOutcome.undecided);
    });

    test(
      'a failed request records nothing so it can be offered again',
      () async {
        final store = InMemoryPromptStore();
        final coordinator = promptCoordinator(
          permissions: FakePermissionGateway(
            requestError: Exception('platform'),
          ),
          store: store,
        );

        expect(await coordinator.enable(), NotificationPromptOutcome.failed);
        expect(store.writes, isEmpty);
        expect(await coordinator.shouldOffer(), isTrue);
      },
    );

    test('registration and storage failures are not fatal', () async {
      final registration = RecordingRegistration()
        ..error = Exception('offline');
      final coordinator = promptCoordinator(
        store: InMemoryPromptStore(writeError: Exception('disk full')),
        registration: registration,
      );

      expect(await coordinator.enable(), NotificationPromptOutcome.enabled);
      await Future<void>.delayed(Duration.zero);
      expect(registration.calls, hasLength(1));
    });
  });

  group('NotificationPromptCoordinator.decline', () {
    test('records the decision without requesting permission', () async {
      final store = InMemoryPromptStore();
      final permissions = FakePermissionGateway();
      final coordinator = promptCoordinator(
        permissions: permissions,
        store: store,
      );

      await coordinator.decline();

      expect(store.writes, [NotificationPromptDecision.declined]);
      expect(permissions.requestCount, 0);
      expect(await coordinator.shouldOffer(), isFalse);
    });

    test('tolerates a storage failure', () async {
      final coordinator = promptCoordinator(
        store: InMemoryPromptStore(writeError: Exception('disk')),
      );

      await coordinator.decline();
    });
  });
}
