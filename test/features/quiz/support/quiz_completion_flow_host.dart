import 'package:flutter/material.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_full_review_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_gameplay_view.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_results_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';

/// Test-only local flow. MQ10 will replace these callbacks with real routes.
class QuizCompletionFlowHost extends StatefulWidget {
  const QuizCompletionFlowHost({
    super.key,
    required this.coordinator,
    required this.createController,
    required this.launcher,
    required this.intent,
  });
  final QuizCompletionCoordinator coordinator;
  final QuizSessionController Function(Future<void> Function(QuizResult) sink)
  createController;
  final SourceLauncher launcher;
  final QuizSaveIntent intent;

  @override
  State<QuizCompletionFlowHost> createState() => _QuizCompletionFlowHostState();
}

class _QuizCompletionFlowHostState extends State<QuizCompletionFlowHost> {
  QuizSessionController? controller;
  String? completionId;
  QuizResult? review;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    controller = widget.createController(
      widget.coordinator.sinkFor(widget.intent),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (finished) return const SizedBox.shrink();
    if (review != null) {
      return QuizFullReviewScreen(
        result: review!,
        sourceLauncher: widget.launcher,
        onDone: () => setState(() => review = null),
      );
    }
    if (completionId != null) {
      return QuizResultsScreen(
        coordinator: widget.coordinator,
        completionId: completionId!,
        onReview: (result) => setState(() => review = result),
        onDone: () => setState(() => finished = true),
      );
    }
    return QuizGameplayView(
      controller: controller!,
      sourceLauncher: widget.launcher,
      onExit: () {},
      onViewResults: (result) {
        controller?.dispose();
        controller = null;
        setState(() => completionId = result.completionId);
      },
    );
  }
}
