import 'event_image.dart';
import 'event_source.dart';

class HistoricalEvent {
  const HistoricalEvent({
    required this.id,
    required this.title,
    required this.year,
    required this.historicalDate,
    required this.summary,
    required this.description,
    required this.sources,
    this.primaryImage,
    this.images = const [],
    this.dateNote,
  }) : assert(id != ''),
       assert(title != ''),
       assert(year != ''),
       assert(historicalDate != ''),
       assert(summary != ''),
       assert(description != ''),
       assert(sources.length > 0);

  final String id;
  final String title;
  final String year;
  final String historicalDate;
  final String summary;
  final String description;
  final List<EventSource> sources;
  final EventImage? primaryImage;
  final List<EventImage> images;
  final String? dateNote;
}
