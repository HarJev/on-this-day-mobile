import 'historical_event_summary.dart';

/// The featured event of one local date before today.
class RecentDay {
  const RecentDay({
    required this.daysAgo,
    required this.displayDate,
    required this.featuredEvent,
  }) : assert(daysAgo > 0),
       assert(displayDate != '');

  /// Calendar distance from today; `1` is yesterday.
  final int daysAgo;
  final String displayDate;
  final HistoricalEventSummary featuredEvent;
}
