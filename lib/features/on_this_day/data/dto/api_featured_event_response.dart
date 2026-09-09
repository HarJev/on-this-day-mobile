import '../../domain/featured_event.dart';
import 'api_event_image_response.dart';
import 'api_json.dart';

class ApiFeaturedEventResponse {
  const ApiFeaturedEventResponse({
    required this.id,
    required this.title,
    required this.year,
    required this.historicalDate,
    required this.summary,
    required this.notificationTitle,
    required this.notificationBody,
    this.image,
    this.dateNote,
  });

  factory ApiFeaturedEventResponse.fromJson(Map<String, Object?> json) {
    final image = json['image'];

    return ApiFeaturedEventResponse(
      id: requiredString(json, 'id'),
      title: requiredString(json, 'title'),
      year: requiredString(json, 'year'),
      historicalDate: requiredString(json, 'historicalDate'),
      summary: requiredString(json, 'summary'),
      notificationTitle: requiredString(json, 'notificationTitle'),
      notificationBody: requiredString(json, 'notificationBody'),
      image: image is Map<String, Object?>
          ? ApiEventImageResponse.fromJson(image)
          : null,
      dateNote: optionalString(json, 'dateNote'),
    );
  }

  final String id;
  final String title;
  final String year;
  final String historicalDate;
  final String summary;
  final String notificationTitle;
  final String notificationBody;
  final ApiEventImageResponse? image;
  final String? dateNote;

  FeaturedEvent toDomain() {
    return FeaturedEvent(
      id: id,
      title: title,
      year: year,
      historicalDate: historicalDate,
      summary: summary,
      notificationTitle: notificationTitle,
      notificationBody: notificationBody,
      image: image?.toDomain(),
      dateNote: dateNote,
    );
  }
}
