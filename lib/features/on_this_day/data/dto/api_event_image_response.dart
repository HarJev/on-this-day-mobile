import '../../domain/event_image.dart';
import 'api_json.dart';

class ApiEventImageResponse {
  const ApiEventImageResponse({
    required this.url,
    required this.altText,
    this.source,
    this.sourceUrl,
    this.attribution,
    this.creator,
    this.license,
    this.licenseUrl,
  });

  factory ApiEventImageResponse.fromJson(Map<String, Object?> json) {
    return ApiEventImageResponse(
      url: requiredUri(json, 'url'),
      altText: requiredString(json, 'altText'),
      source: optionalString(json, 'source'),
      sourceUrl: optionalUri(json, 'sourceUrl'),
      attribution: optionalString(json, 'attribution'),
      creator: optionalString(json, 'creator'),
      license: optionalString(json, 'license'),
      licenseUrl: optionalUri(json, 'licenseUrl'),
    );
  }

  final Uri url;
  final String altText;
  final String? source;
  final Uri? sourceUrl;
  final String? attribution;
  final String? creator;
  final String? license;
  final Uri? licenseUrl;

  EventImage toDomain() {
    return EventImage(
      url: url,
      altText: altText,
      source: source,
      sourceUrl: sourceUrl,
      attribution: attribution,
      creator: creator,
      license: license,
      licenseUrl: licenseUrl,
    );
  }
}
