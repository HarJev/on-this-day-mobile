import 'featured_event.dart';
import 'historical_event_summary.dart';

class DailyContent {
  const DailyContent({
    required this.displayDate,
    required this.featuredEvent,
    required this.additionalEvents,
  }) : assert(displayDate != '');

  final String displayDate;
  final FeaturedEvent featuredEvent;
  final List<HistoricalEventSummary> additionalEvents;
}
