import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/notifications/notification_payload_parser.dart';

void main() {
  const parser = NotificationPayloadParser();

  test('reads eventId from Firebase data', () {
    expect(
      parser.eventIdFromData(const {
        'eventId': 'battle-of-bosworth-field-1485',
      }),
      'battle-of-bosworth-field-1485',
    );
  });

  test('uses the same JSON contract for local notifications', () {
    final payload = parser.toJson('battle-of-bosworth-field-1485');

    expect(payload, '{"eventId":"battle-of-bosworth-field-1485"}');
    expect(parser.eventIdFromJson(payload), 'battle-of-bosworth-field-1485');
  });

  test('rejects missing, blank, or malformed event IDs', () {
    expect(parser.eventIdFromData(const {}), isNull);
    expect(parser.eventIdFromData(const {'eventId': ' '}), isNull);
    expect(parser.eventIdFromJson('{not-json'), isNull);
    expect(parser.eventIdFromJson('["event"]'), isNull);
  });
}
