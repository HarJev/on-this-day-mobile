import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_store.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/event_source.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_exceptions.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/event_detail_screen.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/notification_pre_prompt.dart';

import '../../../core/notifications/support/notification_prompt_fakes.dart';

void main() {
  final prePrompt = find.byKey(const Key('notification-pre-prompt'));
  final outcome = find.byKey(const Key('notification-pre-prompt-outcome'));

  testWidgets('appears at the end of a loaded Event Detail', (tester) async {
    await tester.pumpWidget(_app(coordinator: promptCoordinator()));
    await tester.pumpAndSettle();

    expect(prePrompt, findsOneWidget);
    expect(find.text(NotificationPrePrompt.title), findsOneWidget);
    expect(find.text(NotificationPrePrompt.enableLabel), findsOneWidget);
    expect(find.text(NotificationPrePrompt.declineLabel), findsOneWidget);
    // Placed after the sources.
    expect(
      tester.getTopLeft(prePrompt).dy,
      greaterThan(tester.getTopLeft(find.text('Example Source')).dy),
    );
  });

  testWidgets('is not built until the reader reaches the end', (tester) async {
    final permissions = FakePermissionGateway();
    await tester.pumpWidget(
      _app(
        coordinator: promptCoordinator(permissions: permissions),
        event: _event(description: List.filled(60, _sentence).join(' ')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(NotificationPrePrompt, skipOffstage: false),
      findsNothing,
    );
    expect(permissions.statusReadCount, 0);

    await tester.scrollUntilVisible(prePrompt, 400);
    await tester.pumpAndSettle();

    expect(prePrompt, findsOneWidget);
    expect(permissions.requestCount, 0);
  });

  testWidgets('is absent while loading and when the event fails', (
    tester,
  ) async {
    final pending = _PendingRepository();
    await tester.pumpWidget(
      _app(coordinator: promptCoordinator(), repository: pending),
    );
    await tester.pump();
    expect(find.byType(NotificationPrePrompt), findsNothing);

    await tester.pumpWidget(
      _app(
        coordinator: promptCoordinator(),
        repository: _ThrowingRepository(
          const EventNotFoundException('event-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NotificationPrePrompt), findsNothing);
  });

  testWidgets('Not now hides it and never requests permission', (tester) async {
    final permissions = FakePermissionGateway();
    final store = InMemoryPromptStore();
    await tester.pumpWidget(
      _app(
        coordinator: promptCoordinator(permissions: permissions, store: store),
      ),
    );
    await tester.pumpAndSettle();

    await _tapPromptAction(tester, NotificationPrePrompt.declineLabel);
    await tester.pumpAndSettle();

    expect(prePrompt, findsNothing);
    expect(outcome, findsNothing);
    expect(permissions.requestCount, 0);
    expect(store.decision, NotificationPromptDecision.declined);
  });

  testWidgets('Turn on requests permission once and confirms', (tester) async {
    final permissions = FakePermissionGateway()
      ..pendingRequest = Completer<void>();
    final registration = RecordingRegistration();
    await tester.pumpWidget(
      _app(
        coordinator: promptCoordinator(
          permissions: permissions,
          registration: registration,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapPromptAction(tester, NotificationPrePrompt.enableLabel);
    await tester.pump();

    // While the system dialog is open, both actions are disabled.
    expect(permissions.requestCount, 1);
    final enable = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, NotificationPrePrompt.enableLabel),
    );
    expect(enable.onPressed, isNull);

    permissions.pendingRequest!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Notifications are on.'), findsOneWidget);
    expect(registration.calls, [NotificationPermissionStatus.authorized]);
    expect(permissions.requestCount, 1);
  });

  final outcomes = <(NotificationPermissionStatus?, bool, String)>[
    (NotificationPermissionStatus.denied, false, 'Notifications are off'),
    (
      NotificationPermissionStatus.permanentlyDenied,
      false,
      'Notifications are off',
    ),
    (NotificationPermissionStatus.notDetermined, false, 'weren’t turned on'),
    (null, true, 'couldn’t be turned on right now'),
  ];
  for (final (result, fails, message) in outcomes) {
    testWidgets('shows honest copy when the request ends as $result', (
      tester,
    ) async {
      final permissions = FakePermissionGateway(
        requestResult: result ?? NotificationPermissionStatus.denied,
        requestError: fails ? Exception('platform channel error') : null,
      );
      await tester.pumpWidget(
        _app(coordinator: promptCoordinator(permissions: permissions)),
      );
      await tester.pumpAndSettle();

      await _tapPromptAction(tester, NotificationPrePrompt.enableLabel);
      await tester.pumpAndSettle();

      expect(find.textContaining(message), findsOneWidget);
      for (final technical in [
        'Firebase',
        'FCM',
        'APNs',
        'token',
        'Exception',
      ]) {
        expect(find.textContaining(technical), findsNothing);
      }
    });
  }

  testWidgets('does not appear when notifications are already allowed', (
    tester,
  ) async {
    for (final status in [
      NotificationPermissionStatus.authorized,
      NotificationPermissionStatus.provisional,
      NotificationPermissionStatus.permanentlyDenied,
    ]) {
      await tester.pumpWidget(
        _app(
          key: ValueKey(status),
          coordinator: promptCoordinator(
            permissions: FakePermissionGateway(status: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(prePrompt, findsNothing, reason: '$status');
    }
  });

  testWidgets('a recorded decision keeps it away on later Event Details', (
    tester,
  ) async {
    final store = InMemoryPromptStore();
    final coordinator = promptCoordinator(store: store);
    await tester.pumpWidget(_app(coordinator: coordinator));
    await tester.pumpAndSettle();
    await _tapPromptAction(tester, NotificationPrePrompt.declineLabel);
    await tester.pumpAndSettle();

    // Simulates a later launch opening another event with the same storage.
    await tester.pumpWidget(
      _app(
        key: const ValueKey('second'),
        coordinator: promptCoordinator(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(prePrompt, findsNothing);
  });
}

const _sentence = 'This sentence makes the article long enough to scroll.';

Widget _app({
  Key? key,
  required NotificationPromptCoordinator coordinator,
  OnThisDayRepository? repository,
  HistoricalEvent? event,
}) {
  return MaterialApp(
    key: key,
    theme: AppTheme.light,
    home: EventDetailScreen(
      repository: repository ?? _StaticRepository(event ?? _event()),
      eventId: 'event-1',
      sourceLauncher: const _NoopSourceLauncher(),
      notificationPrompt: coordinator,
    ),
  );
}

HistoricalEvent _event({
  String description =
      'A concise description of what happened and why it mattered.',
}) {
  return HistoricalEvent(
    id: 'event-1',
    title: 'A detailed historical event',
    year: '1485',
    historicalDate: 'August 22, 1485',
    summary: 'A concise summary.',
    description: description,
    sources: [
      EventSource(
        name: 'Example Source',
        url: Uri.parse('https://example.com/history'),
      ),
    ],
  );
}

class _StaticRepository implements OnThisDayRepository {
  _StaticRepository(this.event);

  final HistoricalEvent event;

  @override
  Future<DailyContent> getTodayContent(String timezone) =>
      throw UnimplementedError();

  @override
  Future<HistoricalEvent> getEvent(String eventId) async => event;
}

class _PendingRepository implements OnThisDayRepository {
  final Completer<HistoricalEvent> _completer = Completer<HistoricalEvent>();

  @override
  Future<DailyContent> getTodayContent(String timezone) =>
      throw UnimplementedError();

  @override
  Future<HistoricalEvent> getEvent(String eventId) => _completer.future;
}

class _ThrowingRepository implements OnThisDayRepository {
  _ThrowingRepository(this.error);

  final Object error;

  @override
  Future<DailyContent> getTodayContent(String timezone) =>
      throw UnimplementedError();

  @override
  Future<HistoricalEvent> getEvent(String eventId) async => throw error;
}

class _NoopSourceLauncher implements SourceLauncher {
  const _NoopSourceLauncher();

  @override
  Future<bool> open(Uri url) async => true;
}

Future<void> _tapPromptAction(WidgetTester tester, String label) async {
  final action = find.text(label);
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
}
