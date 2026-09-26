import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparer.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_decoder.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_preparation.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_state.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/widgets/quiz_image_question.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/widgets/quiz_source_row.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import '../support/image_fakes.dart';
import '../support/session_fakes.dart';
import '../support/quiz_gameplay_harness.dart';

class CreditLauncher implements SourceLauncher {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}

void main() {
  late QuizSessionController controller;
  late FakeSessionClock clock;
  late FakeSessionScheduler scheduler;
  late QuizImagePreparer preparer;
  late CreditLauncher launcher;
  late List<QuizResult> completions;
  late int exits, results;
  final captureKey = GlobalKey();
  Future<void> mount(
    WidgetTester tester, {
    bool daily = false,
    double scale = 1,
    PrepareQuizSession? prepare,
    bool start = true,
  }) async {
    clock = FakeSessionClock();
    scheduler = FakeSessionScheduler();
    launcher = CreditLauncher();
    completions = [];
    exits = 0;
    results = 0;
    final bytes = (await tester.runAsync(
      () => testImageBytes(width: 400, height: 200),
    ))!;
    preparer = QuizImagePreparer(
      downloader: BytesDownloader(bytes),
      decoder: FlutterQuizImageDecoder(),
    );
    tester.view.physicalSize = scale == 1
        ? const Size(390, 844)
        : const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: captureKey,
          child: QuizGameplayHarness(
            createController: () {
              controller = QuizSessionController(
                definition: imageQuiz(daily: daily),
                completionId: 'image-completion',
                timingEnabled: true,
                clock: clock,
                scheduler: scheduler,
                prepareSession: prepare ?? preparer.call,
                completionSink: (r) async => completions.add(r),
              );
              return controller;
            },
            launcher: launcher,
            onExit: () => exits++,
            onResults: (_) => results++,
          ),
        ),
      ),
    );
    if (start) {
      await tester.runAsync(controller.prepare);
      await tester.pump();
      await tester.ensureVisible(
        find.text(daily ? 'Start challenge' : 'Start quiz'),
      );
      await tester.tap(find.text(daily ? 'Start challenge' : 'Start quiz'));
      await tester.pump();
    }
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pump();
  }

  // Every string in the fixture credit that could identify a subject.
  const creditStrings = [
    'Test artwork',
    'Test fixture',
    'Fixture archive',
    'CC0',
    'example.org',
  ];

  List<String> semanticsText(WidgetTester tester) {
    var root = tester.getSemantics(find.byType(QuizGameplayHarness));
    while (root.parent != null) {
      root = root.parent!;
    }
    final text = <String>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      text.addAll(
        [
          data.label,
          data.value,
          data.hint,
          data.tooltip,
          data.linkUrl?.toString() ?? '',
        ].where((value) => value.isNotEmpty),
      );
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
    return text;
  }

  void expectCreditHidden(WidgetTester tester) {
    for (final value in creditStrings) {
      expect(
        find.textContaining(value, skipOffstage: false),
        findsNothing,
        reason: 'widget tree exposes "$value" before submission',
      );
    }
    // Only the disabled placeholder tile may exist; no expandable credit.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ExpansionTile && widget.enabled,
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(find.byType(QuizSourceRow, skipOffstage: false), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            creditStrings.any(
              (value) => (widget.message ?? '').contains(value),
            ),
      ),
      findsNothing,
    );
    for (final value in creditStrings) {
      expect(
        semanticsText(tester).where((text) => text.contains(value)),
        isEmpty,
        reason: 'accessibility traversal exposes "$value" before submission',
      );
    }
  }

  Future<void> expectCreditAvailableAndLinksOpen(WidgetTester tester) async {
    expect(find.text(QuizQuestionImage.pendingCreditMessage), findsNothing);
    await tap(tester, 'Image credit');
    await tester.pumpAndSettle();
    expect(find.text('Test artwork'), findsOneWidget);
    expect(find.text('Test fixture'), findsOneWidget);
    await tap(tester, 'Fixture archive');
    await tap(tester, 'CC0');
    expect(launcher.opened, [
      Uri.parse('https://example.org/source'),
      (imageQuiz().questions.first as ImageIdentificationQuestion)
          .image
          .licenseUrl,
    ]);
  }

  testWidgets(
    'real prepared pixels, neutral semantics, contained aspect ratio',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester);
      final raw = tester.widget<RawImage>(find.byType(RawImage));
      expect(raw.fit, BoxFit.contain);
      expect(raw.image!.width / raw.image!.height, 2);
      expect(
        find.bySemanticsLabel('A blue circular form on a pale field'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'while answerable, no credit text, link, tooltip, or semantics is reachable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester);

      expect(controller.state, isA<QuizAnswering>());
      expectCreditHidden(tester);
      // The neutral reviewed alt text is still the image's description.
      expect(
        find.bySemanticsLabel('A blue circular form on a pale field'),
        findsOneWidget,
      );
      // A quiet, non-interactive placeholder holds the row.
      final pending = find.text(QuizQuestionImage.pendingCreditMessage);
      expect(pending, findsOneWidget);
      final node = tester
          .getSemantics(find.byKey(const Key('image-credit-pending')))
          .getSemanticsData();
      expect(node.label, QuizQuestionImage.pendingCreditMessage);
      expect(node.hasAction(SemanticsAction.tap), isFalse);
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.linkUrl, isNull);
      await tester.tap(pending);
      await tester.pump();
      expectCreditHidden(tester);
      expect(launcher.opened, isEmpty);
      semantics.dispose();
    },
  );

  testWidgets('credit becomes available after a correct answer', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mount(tester);
    // Measure relative to the image so scrolling toward feedback is not
    // mistaken for a layout change.
    double belowImage(Finder finder) =>
        tester.getTopLeft(finder).dy -
        tester.getRect(find.byType(RawImage)).bottom;
    final pendingOffset = belowImage(
      find.byKey(const Key('image-credit-pending')),
    );
    final optionOffset = belowImage(find.byKey(const Key('option-a')));

    await tester.tap(find.byKey(const Key('option-a')));
    await tester.pump();

    expect(controller.state, isA<QuizFeedback>());
    // The credit row takes the placeholder's slot, and the answer options
    // below it do not move.
    expect(belowImage(find.byKey(const ValueKey('credit-q-0'))), pendingOffset);
    expect(belowImage(find.byKey(const Key('option-a'))), optionOffset);
    await expectCreditAvailableAndLinksOpen(tester);
    // After submission the credit is reachable through accessibility too.
    expect(
      semanticsText(tester).any((text) => text.contains('Test artwork')),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('credit becomes available after an incorrect answer', (
    tester,
  ) async {
    await mount(tester);

    await tester.tap(find.byKey(const Key('option-b')));
    await tester.pump();

    expect(find.text('Incorrect'), findsOneWidget);
    await expectCreditAvailableAndLinksOpen(tester);
  });

  testWidgets('credit becomes available after a timeout', (tester) async {
    await mount(tester);

    clock.advance(const Duration(seconds: 30));
    scheduler.fire();
    await tester.pump();

    expect(find.text("Time's up"), findsOneWidget);
    await expectCreditAvailableAndLinksOpen(tester);
  });

  testWidgets('credit becomes available after Skip', (tester) async {
    await mount(tester);

    await tap(tester, 'Skip question');

    expect(find.text('Skipped'), findsOneWidget);
    await expectCreditAvailableAndLinksOpen(tester);
  });

  testWidgets(
    'the final question exposes credit in feedback before Results opens',
    (tester) async {
      await mount(tester);
      for (var i = 0; i < 4; i++) {
        await tap(tester, 'Skip question');
        expect(find.text('Image credit'), findsOneWidget);
        await tap(tester, 'Continue');
        // Each new question starts protected again.
        expectCreditHidden(tester);
      }

      await tester.tap(find.byKey(const Key('option-a')));
      await tester.pump();

      expect(controller.state, isA<QuizCompleted>());
      expect(find.text('View results'), findsOneWidget);
      await expectCreditAvailableAndLinksOpen(tester);
      expect(results, 0);
      await tap(tester, 'View results');
      expect(results, 1);
    },
  );

  testWidgets('small-phone large-text layout stays usable before and after', (
    tester,
  ) async {
    await mount(tester, scale: 2);

    expectCreditHidden(tester);
    await tester.ensureVisible(
      find.text(QuizQuestionImage.pendingCreditMessage),
    );
    expect(
      tester.getBottomRight(find.text('Skip question')).dy,
      lessThanOrEqualTo(568),
    );

    await tap(tester, 'Skip question');

    expect(
      tester.getBottomRight(find.text('Continue')).dy,
      lessThanOrEqualTo(568),
    );
    await tester.ensureVisible(find.text('Image credit'));
    await tap(tester, 'Image credit');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test artwork'));
    expect(find.text('Test artwork'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Continue')).dy,
      lessThanOrEqualTo(568),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'skip locks, advances, releases prior image and retains final feedback through completion',
    (tester) async {
      await mount(tester);
      for (var i = 0; i < 5; i++) {
        await tap(tester, 'Skip question');
        expect(find.text('Skipped'), findsOneWidget);
        expect(find.text('Your choice'), findsNothing);
        expect(find.text('Skip question'), findsNothing);
        if (i < 4) {
          await tap(tester, 'Continue');
          await tester.pump();
          expect(controller.preparedImages!.contains('q-$i'), isFalse);
        }
      }
      final displayed = tester.widget<RawImage>(find.byType(RawImage)).image!;
      expect(controller.state, isA<QuizCompleted>());
      expect(completions.single.correct, 0);
      expect(completions.single.unanswered, 5);
      expect(displayed.debugDisposed, isFalse);
      expect(controller.preparedImages!.contains('q-4'), isTrue);
      await tap(tester, 'View results');
      await tester.pump();
      expect(results, 1);
      expect(controller.preparedImages, isNull);
      expect(displayed.debugDisposed, isTrue);
      expect(find.byType(RawImage), findsNothing);
    },
  );
  testWidgets('Daily expiry keeps active image until feedback is left', (
    tester,
  ) async {
    await mount(tester, daily: true);
    clock.advance(const Duration(seconds: 120));
    scheduler.fire();
    await tester.pump();
    expect(find.text("Time's up"), findsOneWidget);
    expect(find.byType(RawImage), findsOneWidget);
    expect(controller.preparedImages!.contains('q-0'), isTrue);
    expect(controller.preparedImages!.contains('q-1'), isFalse);
    expect(find.byKey(const Key('quiz-timer')), findsNothing);
    await tester.tap(find.byTooltip('Leave quiz'));
    await tester.pump();
    expect(exits, 1);
    expect(controller.preparedImages, isNull);
  });
  testWidgets('an incomplete preparation lease cannot become ready', (
    tester,
  ) async {
    var released = 0;
    await mount(
      tester,
      start: false,
      prepare: (_) => QuizPreparationAttempt(
        Future.value(QuizPreparedResources(() => released++)),
      ),
    );
    await controller.prepare();
    await tester.pump();
    controller.start();
    expect(controller.state, isA<QuizPreparationFailed>());
    expect(released, 1);
    expect(scheduler.activeCount, 0);
    expect(completions, isEmpty);
  });
  testWidgets('missing handle wins over answer or deadline without scoring', (
    tester,
  ) async {
    await mount(tester);
    controller.preparedImages!.release();
    clock.advance(const Duration(seconds: 30));
    controller.answerOption('q-0', 'a');
    await tester.pump();
    expect(controller.state, isA<QuizInterrupted>());
    expect(completions, isEmpty);
    expect(find.text('Quiz interrupted'), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);
  });
  testWidgets(
    'preparation failure retries with a fresh attempt and no elapsed budget',
    (tester) async {
      final failed = FakePreparation();
      var calls = 0;
      await mount(
        tester,
        start: false,
        prepare: (quiz) =>
            calls++ == 0 ? failed.call(quiz) : preparer.call(quiz),
      );
      final pending = controller.prepare();
      controller.start();
      clock.advance(const Duration(hours: 1));
      expect(controller.state, isA<QuizPreparing>());
      expect(scheduler.activeCount, 0);
      failed.pending.single.completeError(StateError('bad image'));
      await pending;
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Images ready'), findsNothing);
      expect(find.text('Images unavailable'), findsOneWidget);
      expect(completions, isEmpty);
      await tester.runAsync(controller.prepare);
      await tester.pump();
      expect(controller.state, isA<QuizReady>());
      expect(scheduler.activeCount, 0);
      await tap(tester, 'Start quiz');
      expect(
        (controller.state as QuizAnswering).remaining,
        const Duration(seconds: 30),
      );
    },
  );
  testWidgets(
    'stale and disposed preparation leases release decoded originals',
    (tester) async {
      final fake = FakePreparation();
      await mount(tester, start: false, prepare: fake.call);
      final old = controller.prepare();
      final current = controller.prepare();
      final stale = (await tester.runAsync(
        () => preparer.call(controller.definition).result,
      ))!;
      fake.pending[0].complete(stale);
      await old;
      expect(stale.images!.contains('q-0'), isFalse);
      await tester.pumpWidget(const SizedBox());
      final late = (await tester.runAsync(
        () => preparer.call(controller.definition).result,
      ))!;
      fake.pending[1].complete(late);
      await current;
      expect(late.images!.contains('q-0'), isFalse);
      expect(completions, isEmpty);
    },
  );
  testWidgets('exit during preparation cancels without scored result', (
    tester,
  ) async {
    final fake = FakePreparation();
    await mount(tester, start: false, prepare: fake.call);
    final pending = controller.prepare();
    await tester.pump();
    await tester.tap(find.byTooltip('Leave quiz'));
    await tester.pumpAndSettle();
    await tap(tester, 'Leave');
    await tester.pumpAndSettle();
    expect(fake.cancellations, 1);
    expect(exits, 1);
    expect(completions, isEmpty);
    fake.succeed();
    await pending;
    expect(fake.releases, 1);
  });
  testWidgets('image feedback screenshots and large-text controls', (
    tester,
  ) async {
    const destination = String.fromEnvironment('QUIZ_IMAGE_SCREENSHOT_DIR');
    if (destination.isNotEmpty) {
      for (final entry in {
        'Roboto': '/System/Library/Fonts/Supplemental/Arial.ttf',
        'Georgia': '/System/Library/Fonts/Supplemental/Georgia.ttf',
        'MaterialIcons':
            '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final bytes = (await tester.runAsync(
          () => File(entry.value).readAsBytes(),
        ))!;
        await (FontLoader(
          entry.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    }
    Future<void> capture(String name) async {
      if (destination.isEmpty) return;
      await tester.pumpAndSettle();
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(destination).create(recursive: true);
          await File(
            '$destination/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    await mount(tester, daily: true, start: false);
    await tester.runAsync(controller.prepare);
    await tester.pump();
    await capture('session-ready');
    expect(tester.getTopLeft(find.text('Start challenge')).dy, lessThan(400));
    await tap(tester, 'Start challenge');
    await capture('image-answering');
    await tap(tester, 'Skip question');
    await capture('image-skipped');
    await tap(tester, 'Image credit');
    await capture('image-skipped-credit-expanded');
    await tester.pumpWidget(const SizedBox());
    await mount(tester, scale: 2);
    expect(
      tester.getBottomRight(find.text('Skip question')).dy,
      lessThanOrEqualTo(568),
    );
    await tester.ensureVisible(find.byType(RawImage));
    await capture('image-large-text');
    await tap(tester, 'Skip question');
    expect(
      tester.getBottomRight(find.text('Continue')).dy,
      lessThanOrEqualTo(568),
    );
    await capture('image-large-feedback');
    expect(tester.takeException(), isNull);
  });
}
