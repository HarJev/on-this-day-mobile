import 'package:flutter/material.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_gameplay_view.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';

/// Owns the same production view without exposing a developer route in the app.
class QuizGameplayHarness extends StatefulWidget {
  const QuizGameplayHarness({
    super.key,
    required this.createController,
    required this.launcher,
    required this.onExit,
    required this.onResults,
  });
  final QuizSessionController Function() createController;
  final SourceLauncher launcher;
  final VoidCallback onExit;
  final ValueChanged<QuizResult> onResults;
  @override
  State<QuizGameplayHarness> createState() => _QuizGameplayHarnessState();
}

class _QuizGameplayHarnessState extends State<QuizGameplayHarness>
    with WidgetsBindingObserver {
  late final QuizSessionController controller;
  @override
  void initState() {
    super.initState();
    controller = widget.createController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      controller.setAppActive(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuizGameplayView(
    controller: controller,
    sourceLauncher: widget.launcher,
    onExit: widget.onExit,
    onViewResults: widget.onResults,
  );
}
