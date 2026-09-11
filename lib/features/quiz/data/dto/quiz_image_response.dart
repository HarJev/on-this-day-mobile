import '../../domain/quiz_image.dart';
import 'quiz_json.dart';

final class QuizImageResponse {
  QuizImageResponse.fromJson(QuizJson json)
    : url = Uri.parse(json.string('url')),
      altText = json.string('altText'),
      source = json.string('source'),
      sourceUrl = Uri.parse(json.string('sourceUrl')),
      attribution = json.string('attribution'),
      creator = json.nullableString('creator'),
      license = json.string('license'),
      licenseUrl = Uri.parse(json.string('licenseUrl'));
  final Uri url, sourceUrl, licenseUrl;
  final String altText, source, attribution, license;
  final String? creator;
  QuizImage toDomain() => QuizImage(
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
