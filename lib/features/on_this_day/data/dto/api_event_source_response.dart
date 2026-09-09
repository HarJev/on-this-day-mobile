import '../../domain/event_source.dart';
import 'api_json.dart';

class ApiEventSourceResponse {
  const ApiEventSourceResponse({required this.name, required this.url});

  factory ApiEventSourceResponse.fromJson(Map<String, Object?> json) {
    return ApiEventSourceResponse(
      name: requiredString(json, 'name'),
      url: requiredUri(json, 'url'),
    );
  }

  final String name;
  final Uri url;

  EventSource toDomain() {
    return EventSource(name: name, url: url);
  }
}
