import '../../domain/quiz_source.dart';
import 'quiz_json.dart';

final class QuizSourceResponse {
  QuizSourceResponse.fromJson(QuizJson json)
    : displayName = json.string('displayName'),
      url = Uri.parse(json.string('url'));
  final String displayName;
  final Uri url;
  QuizSource toDomain() => QuizSource(displayName: displayName, url: url);
}
