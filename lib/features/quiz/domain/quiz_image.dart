import 'quiz_validation.dart';

final class QuizImage {
  QuizImage({
    required this.url,
    required this.altText,
    required this.source,
    required this.sourceUrl,
    required this.attribution,
    this.creator,
    required this.license,
    required this.licenseUrl,
  }) {
    for (final uri in [url, sourceUrl, licenseUrl]) {
      requireHttps(uri);
    }
    for (final text in [altText, source, attribution, license]) {
      requireText(text);
    }
    if (creator != null) requireText(creator!);
  }
  final Uri url, sourceUrl, licenseUrl;
  final String altText, source, attribution, license;
  final String? creator;
}
