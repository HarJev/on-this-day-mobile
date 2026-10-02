import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_store.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';

import 'support/notification_prompt_fakes.dart';

void main() {
  group('NotificationPromptCoordinator.shouldOffer by permission', () {
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

    test('is false when the permission status cannot be read', () async {
      final coordinator = promptCoordinator(
        permissions: FakePermissionGateway(statusError: Exception('channel')),
      );

      expect(await coordinator.shouldOffer(), isFalse);
    });
  });

  group('NotificationPromptCoordinator "Not now" policy', () {
    test('first decline records declinedAt and declineCount 1', () async {
      final clock = FakeClock();
      final store = InMemoryPromptStore();
      final permissions = FakePermissionGateway();
      final coordinator = promptCoordinator(
        permissions: permissions,
        store: store,
        now: clock.call,
      );

      await coordinator.decline();

      expect(
        store.record,
        NotificationPromptRecord(declineCount: 1, declinedAt: clock.now),
      );
      expect(permissions.requestCount, 0);
    });

    test('re-offers only once 30 days have passed', () async {
      final clock = FakeClock();
      final store = InMemoryPromptStore();
      final coordinator = promptCoordinator(store: store, now: clock.call);
      await coordinator.decline();

      clock.advance(
        NotificationPromptCoordinator.reofferAfter -
            const Duration(milliseconds: 1),
      );
      expect(await coordinator.shouldOffer(), isFalse);

      clock.advance(const Duration(milliseconds: 1));
      expect(await coordinator.shouldOffer(), isTrue);
    });

    test('a second decline suppresses all future offers', () async {
      final clock = FakeClock();
      final store = InMemoryPromptStore();
      final coordinator = promptCoordinator(store: store, now: clock.call);
      await coordinator.decline();
      clock.advance(NotificationPromptCoordinator.reofferAfter);

      await coordinator.decline();

      expect(store.record!.declineCount, 2);
      expect(store.record!.declinedAt, clock.now);
      clock.advance(const Duration(days: 3650));
      expect(await coordinator.shouldOffer(), isFalse);
    });

    test('a completed system request is permanent', () async {
      final clock = FakeClock();
      final store = InMemoryPromptStore(
        record: const NotificationPromptRecord(requested: true),
      );
      final permissions = FakePermissionGateway();
      final coordinator = promptCoordinator(
        permissions: permissions,
        store: store,
        now: clock.call,
      );

      clock.advance(const Duration(days: 3650));
      expect(await coordinator.shouldOffer(), isFalse);
      expect(permissions.statusReadCount, 0);
    });

    test('a re-offer still respects permission state', () async {
      final clock = FakeClock();
      final store = InMemoryPromptStore(
        record: NotificationPromptRecord(
          declineCount: 1,
          declinedAt: clock.now,
        ),
      );
      final coordinator = promptCoordinator(
        permissions: FakePermissionGateway(
          status: NotificationPermissionStatus.authorized,
        ),
        store: store,
        now: clock.call,
      );

      clock.advance(const Duration(days: 31));
      expect(await coordinator.shouldOffer(), isFalse);
    });

    test('a decline without a recorded time fails closed', () async {
      final coordinator = promptCoordinator(
        store: InMemoryPromptStore(
          record: const NotificationPromptRecord(declineCount: 1),
        ),
      );

      expect(await coordinator.shouldOffer(), isFalse);
    });

    test(
      'unreadable preference data fails closed and is not overwritten',
      () async {
        final store = InMemoryPromptStore(
          readError: const FormatException('x'),
        );
        final permissions = FakePermissionGateway();
        final coordinator = promptCoordinator(
          permissions: permissions,
          store: store,
        );

        expect(await coordinator.shouldOffer(), isFalse);
        await coordinator.decline();
        expect(store.writes, isEmpty);
        expect(permissions.statusReadCount, 0);
      },
    );
  });

  group('NotificationPromptCoordinator.enable', () {
    test(
      'authorized: records the request and registers in the background',
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
        expect(store.record, const NotificationPromptRecord(requested: true));
        expect(registration.calls, [NotificationPermissionStatus.authorized]);
        registration.pending!.complete();
      },
    );

    test('keeps an earlier decline when the request completes', () async {
      final clock = FakeClock();
      final store = InMemoryPromptStore(
        record: NotificationPromptRecord(
          declineCount: 1,
          declinedAt: clock.now,
        ),
      );
      final coordinator = promptCoordinator(store: store, now: clock.call);

      await coordinator.enable();

      expect(
        store.record,
        NotificationPromptRecord(
          requested: true,
          declineCount: 1,
          declinedAt: clock.now,
        ),
      );
    });

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
        expect(store.record!.requested, isTrue);
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

  test('decline tolerates a storage write failure', () async {
    final coordinator = promptCoordinator(
      store: InMemoryPromptStore(writeError: Exception('disk')),
    );

    await coordinator.decline();
  });

  test('reports only fixed notification decisions', () async {
    final decisions = <String>[];
    final coordinator = promptCoordinator(
      onDecision: decisions.add,
      permissions: FakePermissionGateway(
        requestResult: NotificationPermissionStatus.authorized,
      ),
    );

    await coordinator.decline();
    expect(await coordinator.enable(), NotificationPromptOutcome.enabled);
    expect(decisions, ['not_now', 'enabled']);
  });
}
