import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/notifications/notification_resume_reconciler.dart';

void main() {
  Future<void> backgroundThenResume(WidgetTester tester) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
  }

  testWidgets('reconciles each time the app resumes', (tester) async {
    var calls = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final reconciler = NotificationResumeReconciler(
      reconcile: () async => calls += 1,
    )..start();
    addTearDown(reconciler.dispose);

    await backgroundThenResume(tester);
    expect(calls, 1);

    await backgroundThenResume(tester);
    expect(calls, 2);
  });

  testWidgets('a failing reconciliation is contained', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final reconciler = NotificationResumeReconciler(
      reconcile: () => Future<void>.error(Exception('offline')),
    )..start();
    addTearDown(reconciler.dispose);

    await backgroundThenResume(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('stops listening after dispose', (tester) async {
    var calls = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final reconciler = NotificationResumeReconciler(
      reconcile: () async => calls += 1,
    )..start();
    reconciler.dispose();

    await backgroundThenResume(tester);

    expect(calls, 0);
  });
}
