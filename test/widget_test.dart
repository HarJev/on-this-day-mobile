import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/main.dart';

void main() {
  testWidgets('application shell boots', (WidgetTester tester) async {
    await tester.pumpWidget(const OnThisDayApp());

    expect(find.text('On This Day'), findsOneWidget);
  });
}
