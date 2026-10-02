import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/config/app_config.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/backend_on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/home_screen.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/featured_event_card.dart';
import 'package:on_this_day_mobile/features/quiz/data/backend_quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_hub_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('LIVE_API_READ_SMOKE');

  testWidgets(
    'deployed Today and Quiz catalog load without notification registration',
    (tester) async {
      final baseUrl = AppConfig.fromEnvironment().apiBaseUrl;
      expect(baseUrl, Uri.parse('https://d1v4ivrcr6v8za.cloudfront.net'));
      final httpClient = http.Client();
      addTearDown(httpClient.close);
      final api = ApiClient(baseUrl: baseUrl, httpClient: httpClient);
      final today = BackendOnThisDayRepository(apiClient: api);
      final quiz = BackendQuizRepository(apiClient: api);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            repository: today,
            timezoneProvider: const _JamaicaTimezone(),
          ),
        ),
      );
      await _waitFor(tester, find.byType(FeaturedEventCard));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: QuizHubScreen(
            repository: quiz,
            onOpenDaily: (_) {},
            onOpenQuickPlay: (_) {},
          ),
        ),
      );
      await _waitFor(tester, find.text('Set up a quick round'));
      expect(tester.takeException(), isNull);

      final round = await quiz.createQuickPlay(questionCount: 5);
      expect(round.questions, hasLength(5));
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for live screen content.');
}

final class _JamaicaTimezone implements TimezoneProvider {
  const _JamaicaTimezone();

  @override
  Future<String> currentTimezone() async => 'America/Jamaica';
}
