import 'event_image.dart';

class FeaturedEvent {
  const FeaturedEvent({
    required this.id,
    required this.title,
    required this.year,
    required this.historicalDate,
    required this.summary,
    required this.notificationTitle,
    required this.notificationBody,
    this.image,
    this.dateNote,
  }) : assert(id != ''),
       assert(title != ''),
       assert(year != ''),
       assert(historicalDate != ''),
       assert(summary != ''),
       assert(notificationTitle != ''),
       assert(notificationBody != '');

  final String id;
  final String title;
  final String year;
  final String historicalDate;
  final String summary;
  final String notificationTitle;
  final String notificationBody;
  final EventImage? image;
  final String? dateNote;
}
