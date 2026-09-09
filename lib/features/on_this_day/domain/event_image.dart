class EventImage {
  const EventImage({
    required this.url,
    required this.altText,
    this.source,
    this.sourceUrl,
    this.attribution,
    this.creator,
    this.license,
    this.licenseUrl,
  }) : assert(altText != '');

  final Uri url;
  final String altText;
  final String? source;
  final Uri? sourceUrl;
  final String? attribution;
  final String? creator;
  final String? license;
  final Uri? licenseUrl;
}
