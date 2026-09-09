import '../../domain/historical_event.dart';
import 'api_event_image_response.dart';
import 'api_event_source_response.dart';
import 'api_json.dart';

class EventDetailResponse {
  const EventDetailResponse({
    required this.id,
    required this.title,
    required this.year,
    required this.historicalDate,
    required this.summary,
    required this.description,
    required this.sources,
    required this.images,
    this.primaryImage,
    this.dateNote,
  });

  factory EventDetailResponse.fromJson(Map<String, Object?> json) {
    final primaryImage = json['primaryImage'];

    return EventDetailResponse(
      id: requiredString(json, 'id'),
      title: requiredString(json, 'title'),
      year: requiredString(json, 'year'),
      historicalDate: requiredString(json, 'historicalDate'),
      summary: requiredString(json, 'summary'),
      description: requiredString(json, 'description'),
      sources: requiredObjectList(
        json,
        'sources',
      ).map(ApiEventSourceResponse.fromJson).toList(growable: false),
      primaryImage: primaryImage is Map<String, Object?>
          ? ApiEventImageResponse.fromJson(primaryImage)
          : null,
      images: requiredObjectList(
        json,
        'images',
      ).map(ApiEventImageResponse.fromJson).toList(growable: false),
      dateNote: optionalString(json, 'dateNote'),
    );
  }

  final String id;
  final String title;
  final String year;
  final String historicalDate;
  final String summary;
  final String description;
  final List<ApiEventSourceResponse> sources;
  final ApiEventImageResponse? primaryImage;
  final List<ApiEventImageResponse> images;
  final String? dateNote;

  HistoricalEvent toDomain() {
    return HistoricalEvent(
      id: id,
      title: title,
      year: year,
      historicalDate: historicalDate,
      summary: summary,
      description: description,
      sources: sources
          .map((source) => source.toDomain())
          .toList(growable: false),
      primaryImage: primaryImage?.toDomain(),
      images: images.map((image) => image.toDomain()).toList(growable: false),
      dateNote: dateNote,
    );
  }
}
