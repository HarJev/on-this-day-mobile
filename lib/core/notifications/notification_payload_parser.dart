import 'dart:convert';

class NotificationPayloadParser {
  const NotificationPayloadParser();

  String? eventIdFromData(Map<String, Object?>? data) {
    final eventId = data?['eventId'];
    if (eventId is String && eventId.trim().isNotEmpty) {
      return eventId;
    }

    return null;
  }

  String? eventIdFromJson(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return eventIdFromData(decoded);
    } on FormatException {
      return null;
    }
  }

  String toJson(String eventId) {
    return jsonEncode({'eventId': eventId});
  }
}
