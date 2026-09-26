import '../domain/quiz_definition.dart';
import 'images/prepared_quiz_images.dart';

typedef PrepareQuizSession =
    QuizPreparationAttempt Function(QuizDefinition quiz);

/// A lease also returned by stale attempts, so their resources can be released.
final class QuizPreparedResources {
  QuizPreparedResources(this._onRelease, {this.images});
  final PreparedQuizImages? images;
  final void Function() _onRelease;
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    images?.release();
    _onRelease();
  }
}

final class QuizPreparationAttempt {
  QuizPreparationAttempt(this.result, {void Function()? onCancel})
    : _onCancel = onCancel;
  final Future<QuizPreparedResources> result;
  final void Function()? _onCancel;
  bool _cancelled = false;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }
}
