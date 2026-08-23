class HistoricalEventSummary {
  const HistoricalEventSummary({
    required this.id,
    required this.title,
    required this.year,
    required this.historicalDate,
    this.dateNote,
  }) : assert(id != ''),
       assert(title != ''),
       assert(year != ''),
       assert(historicalDate != '');

  final String id;
  final String title;
  final String year;
  final String historicalDate;
  final String? dateNote;
}
