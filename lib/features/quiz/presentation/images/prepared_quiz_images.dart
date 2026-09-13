import 'dart:ui' as ui;

/// Owns one handle per unique URL. Widgets own clones, never these handles.
final class PreparedQuizImages {
  PreparedQuizImages(Map<String, Uri> questions, Map<Uri, ui.Image> images)
    : _questions = Map.of(questions),
      _images = Map.of(images);
  final Map<String, Uri> _questions;
  final Map<Uri, ui.Image> _images;
  bool contains(String questionId) =>
      _images.containsKey(_questions[questionId]);
  ui.Image? acquire(String questionId) =>
      _images[_questions[questionId]]?.clone();
  void retainQuestions(Iterable<String> ids) {
    final retained = ids.toSet();
    _questions.removeWhere((key, _) => !retained.contains(key));
    final urls = _questions.values.toSet();
    for (final url in _images.keys.toList()) {
      if (!urls.contains(url)) _images.remove(url)!.dispose();
    }
  }

  void release() => retainQuestions(const []);
}
