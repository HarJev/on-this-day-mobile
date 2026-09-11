import 'quiz_validation.dart';

final class QuizSource {
  QuizSource({required this.displayName, required this.url}) {
    requireText(displayName);
    requireHttps(url);
  }
  final String displayName;
  final Uri url;
}
