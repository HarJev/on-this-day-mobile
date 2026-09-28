import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/images/cached_optional_image_loader.dart';
import 'package:on_this_day_mobile/core/images/image_request_cancellation.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/fake_on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/recent_day.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/event_detail_screen.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/home_screen.dart';

import '../../../support/capture_fonts.dart';

/// Opt-in normal-phone captures of Today and Event Detail for design review:
/// `flutter test --dart-define=TODAY_SCREENSHOT_DIR=<dir> <this file>`.
void main() {
  const destination = String.fromEnvironment('TODAY_SCREENSHOT_DIR');

  testWidgets('representative Today and Event Detail screenshots', (
    tester,
  ) async {
    if (destination.isEmpty) return;
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadCaptureFonts(tester);
    final painting = (await tester.runAsync(
      () => File(
        'design/claude-design/phase-2/design/assets/bosworth-painting.png',
      ).readAsBytes(),
    ))!;
    final loader = _BytesLoader(painting);
    final captureKey = GlobalKey();

    Future<void> capture(String name, Widget home, {bool tall = false}) async {
      tester.view.physicalSize = Size(780, tall ? 3600 : 1688);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: captureKey,
            child: KeyedSubtree(key: ValueKey(name), child: home),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(() async {
        await Directory(destination).create(recursive: true);
        await File(
          '$destination/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    final repository = FakeOnThisDayRepository();
    await capture(
      'today-with-image',
      HomeScreen(
        repository: repository,
        timezoneProvider: const _Timezone(),
        imageLoader: loader,
        sourceLauncher: const _NoopLauncher(),
      ),
      tall: true,
    );
    await capture(
      'today-no-image',
      HomeScreen(
        repository: repository,
        timezoneProvider: const _Timezone(),
        sourceLauncher: const _NoopLauncher(),
      ),
    );
    await capture(
      'today-loading',
      HomeScreen(
        repository: _PendingRepository(),
        timezoneProvider: const _Timezone(),
      ),
    );
    await capture(
      'today-error',
      HomeScreen(
        repository: _FailingRepository(),
        timezoneProvider: const _Timezone(),
      ),
    );
    await capture(
      'detail-with-image',
      EventDetailScreen(
        repository: repository,
        eventId: 'battle-of-bosworth-field-1485',
        sourceLauncher: const _NoopLauncher(),
        imageLoader: loader,
        onTestWhatYouLearned: () {},
      ),
      tall: true,
    );
    await capture(
      'detail-no-image',
      EventDetailScreen(
        repository: repository,
        eventId: 'battle-of-bosworth-field-1485',
        sourceLauncher: const _NoopLauncher(),
        onTestWhatYouLearned: () {},
      ),
    );
    await capture(
      'detail-loading',
      EventDetailScreen(
        repository: _PendingRepository(),
        eventId: 'event-1',
        sourceLauncher: const _NoopLauncher(),
      ),
    );
    await capture(
      'detail-error',
      EventDetailScreen(
        repository: _FailingRepository(),
        eventId: 'event-1',
        sourceLauncher: const _NoopLauncher(),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

final class _BytesLoader implements OptionalImageLoader {
  _BytesLoader(this.bytes);

  final List<int> bytes;

  @override
  Future<ui.Image> load(Uri url, ImageRequestCancellation cancellation) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    return (await codec.getNextFrame()).image;
  }
}

final class _Timezone implements TimezoneProvider {
  const _Timezone();
  @override
  Future<String> currentTimezone() async => 'Etc/UTC';
}

final class _NoopLauncher implements SourceLauncher {
  const _NoopLauncher();
  @override
  Future<bool> open(Uri url) async => true;
}

final class _PendingRepository implements OnThisDayRepository {
  @override
  Future<DailyContent> getTodayContent(String timezone) =>
      Completer<DailyContent>().future;
  @override
  Future<List<RecentDay>> getRecentDays(String timezone) =>
      Completer<List<RecentDay>>().future;
  @override
  Future<HistoricalEvent> getEvent(String eventId) =>
      Completer<HistoricalEvent>().future;
}

final class _FailingRepository implements OnThisDayRepository {
  @override
  Future<DailyContent> getTodayContent(String timezone) async =>
      throw StateError('offline');
  @override
  Future<List<RecentDay>> getRecentDays(String timezone) async => const [];
  @override
  Future<HistoricalEvent> getEvent(String eventId) async =>
      throw StateError('offline');
}
