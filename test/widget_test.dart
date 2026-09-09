import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/navigation/app_router.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/fake_on_this_day_repository.dart';
import 'package:on_this_day_mobile/main.dart';

void main() {
  testWidgets('application shell boots', (WidgetTester tester) async {
    await tester.pumpWidget(
      OnThisDayApp(
        router: AppRouter(
          repository: FakeOnThisDayRepository(),
          timezoneProvider: const _FixedTimezoneProvider('Etc/UTC'),
        ),
      ),
    );

    expect(find.text('On This Day'), findsOneWidget);
    expect(find.text("Loading today's history..."), findsOneWidget);
  });
}

class _FixedTimezoneProvider implements TimezoneProvider {
  const _FixedTimezoneProvider(this.timezone);

  final String timezone;

  @override
  Future<String> currentTimezone() async {
    return timezone;
  }
}
