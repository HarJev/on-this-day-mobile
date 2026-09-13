import 'package:flutter/material.dart';
import '../../../core/navigation/source_launcher.dart';
import '../domain/quiz_definition.dart';
import '../domain/quiz_question.dart';
import '../domain/quiz_result.dart';
import '../domain/question_outcome.dart';
import 'quiz_session_controller.dart';
import 'quiz_session_state.dart';
import 'widgets/quiz_gameplay_header.dart';
import 'widgets/quiz_choice_question.dart';
import 'widgets/quiz_answer_feedback.dart';
import 'widgets/quiz_image_question.dart';
import 'images/quiz_image_preparation_exception.dart';

/// Borrows the controller. The host owns disposal and app/route lifecycle signals.
class QuizGameplayView extends StatefulWidget {
  const QuizGameplayView({
    super.key,
    required this.controller,
    required this.sourceLauncher,
    required this.onExit,
    required this.onViewResults,
  });
  final QuizSessionController controller;
  final SourceLauncher sourceLauncher;
  final VoidCallback onExit;
  final ValueChanged<QuizResult> onViewResults;
  @override
  State<QuizGameplayView> createState() => _QuizGameplayViewState();
}

class _QuizGameplayViewState extends State<QuizGameplayView> {
  final scroll = ScrollController();
  final headingFocus = FocusNode(debugLabel: 'Quiz question heading');
  bool exitPending = false, exited = false, resultsOpened = false;
  String? continuedQuestion;
  String? questionId;
  String announcement = '';
  String? feedbackKey;
  String? warningKey;
  QuizSessionController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    controller.addListener(changed);
  }

  @override
  void didUpdateWidget(QuizGameplayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(changed);
      controller.addListener(changed);
      questionId = null;
      feedbackKey = null;
      warningKey = null;
      continuedQuestion = null;
      resultsOpened = false;
      exited = false;
    }
  }

  @override
  void dispose() {
    controller.removeListener(changed);
    scroll.dispose();
    headingFocus.dispose();
    super.dispose();
  }

  // Accessibility text changes only at meaningful transitions, never each tick.
  void changed() {
    final state = controller.state;
    final context = questionContext(state);
    if (context != null && questionId != context.$2.id) {
      questionId = context.$2.id;
      announcement = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || questionId != context.$2.id) return;
        if (scroll.hasClients) scroll.jumpTo(0);
        headingFocus.requestFocus();
      });
    }
    final outcome = context?.$3;
    final expired =
        state is QuizCompleted &&
        state.result.reason == QuizCompletionReason.dailyTimeExpired;
    if (outcome != null) {
      final key = '${outcome.question.id}:${outcome.kind}:$expired';
      if (feedbackKey != key) {
        feedbackKey = key;
        announcement = QuizAnswerFeedback.label(outcome, expired);
      }
    }
    if (outcome == null ||
        (controller.definition is DailyQuizDefinition && !expired)) {
      final remaining = remainingTime(state);
      final key = controller.definition is DailyQuizDefinition
          ? 'daily'
          : questionId;
      if (remaining != null &&
          remaining <= const Duration(seconds: 5) &&
          warningKey != key) {
        warningKey = key;
        announcement = 'Five seconds remaining';
      }
    }
    setState(() {});
  }

  (int, QuizQuestion, QuestionOutcome?)? questionContext(
    QuizSessionState state,
  ) {
    if (state is QuizAnswering) return (state.index, state.question, null);
    if (state is QuizFeedback) {
      return (state.index, state.outcome.question, state.outcome);
    }
    if (state is QuizCompleted) {
      final index = state.result.outcomes.lastIndexWhere(
        (o) => o.unansweredReason != UnansweredReason.notReached,
      );
      final outcome = state.result.outcomes[index];
      return (index, outcome.question, outcome);
    }
    return null;
  }

  Duration? remainingTime(QuizSessionState state) => switch (state) {
    QuizAnswering(:final remaining) ||
    QuizFeedback(:final remaining) => remaining,
    _ => null,
  };
  Future<void> exit() async {
    if (exitPending || exited) return;
    exitPending = true;
    final state = controller.state;
    final terminal =
        state is QuizCompleted ||
        state is QuizAbandoned ||
        state is QuizInterrupted;
    final confirmed =
        terminal ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Leave quiz?'),
                content: const Text(
                  'This unfinished attempt will not be scored.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Leave'),
                  ),
                ],
              ),
            ) ==
            true;
    exitPending = false;
    if (!mounted || !confirmed) return;
    controller.abandon();
    controller.releaseCompletedImages();
    setState(() {
      exited = true;
    });
    widget.onExit();
  }

  void advance(String id) {
    if (continuedQuestion == id) return;
    controller.continueQuiz(id);
    // Hidden Continue is a no-op and must remain usable on return.
    if (controller.state is! QuizFeedback ||
        (controller.state as QuizFeedback).outcome.question.id != id) {
      continuedQuestion = id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final current = questionContext(state);
    final daily = controller.definition is DailyQuizDefinition;
    final expired =
        state is QuizCompleted &&
        state.result.reason == QuizCompletionReason.dailyTimeExpired;
    final q = current?.$2;
    if (q is ChronologicalOrderingQuestion) {
      throw UnsupportedError('Ordering gameplay is not implemented yet');
    }
    final needsImage =
        q is ImageIdentificationQuestion && !resultsOpened && !exited;
    final missingImage =
        needsImage && controller.preparedImages?.contains(q.id) != true;
    if (missingImage && state is! QuizCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(controller.state, state)) {
          controller.interrupt(
            const QuizImagePreparationException(QuizImageFailure.missing),
          );
        }
      });
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'On This Day',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: ['Times New Roman', 'serif'],
              fontSize: 21,
            ),
          ),
          leading: IconButton(
            tooltip: 'Leave quiz',
            onPressed: exit,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Column(
          children: [
            if (current != null)
              QuizGameplayHeader(
                daily: daily,
                index: current.$1,
                count: controller.definition.questionCount,
                remaining: remainingTime(state),
              ),
            Semantics(
              liveRegion: true,
              label: announcement,
              child: const SizedBox.shrink(),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: missingImage
                    ? const Text('Quiz image unavailable.')
                    : current == null
                    ? Text(switch (state) {
                        QuizPreparing() => 'Preparing quiz',
                        QuizReady() => 'Ready',
                        QuizPreparationFailed() => 'Could not prepare quiz.',
                        QuizAbandoned() => 'Quiz ended',
                        _ => 'Quiz interrupted',
                      })
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          QuizChoiceQuestion(
                            question: q as ChoiceQuestion,
                            headingFocus: headingFocus,
                            outcome: current.$3,
                            image: needsImage
                                ? QuizQuestionImage(
                                    key: ValueKey((
                                      controller.preparedImages,
                                      q.id,
                                    )),
                                    questionId: q.id,
                                    images: controller.preparedImages!,
                                    metadata: q.image,
                                    launcher: widget.sourceLauncher,
                                  )
                                : null,
                            onAnswer: (id) => controller.answerOption(q.id, id),
                          ),
                          if (current.$3 != null)
                            QuizAnswerFeedback(
                              outcome: current.$3!,
                              daily: daily,
                              expired: expired,
                              launcher: widget.sourceLauncher,
                              showLabel: q is! ImageIdentificationQuestion,
                            ),
                        ],
                      ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButtonTheme(
                    data: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (q is ImageIdentificationQuestion &&
                            current?.$3 != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              QuizAnswerFeedback.label(current!.$3!, expired),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        switch (state) {
                          QuizFeedback(:final outcome) => FilledButton(
                            onPressed: () => advance(outcome.question.id),
                            child: const Text('Continue'),
                          ),
                          QuizCompleted(:final result) => FilledButton(
                            onPressed: resultsOpened
                                ? null
                                : () {
                                    if (resultsOpened) return;
                                    setState(() {
                                      resultsOpened = true;
                                    });
                                    controller.releaseCompletedImages();
                                    widget.onViewResults(result);
                                  },
                            child: const Text('View results'),
                          ),
                          QuizReady() => FilledButton(
                            onPressed: controller.start,
                            child: const Text('Start'),
                          ),
                          QuizPreparationFailed() => FilledButton(
                            onPressed: controller.prepare,
                            child: const Text('Retry'),
                          ),
                          QuizAnswering(:final question)
                              when question is ImageIdentificationQuestion &&
                                  !missingImage =>
                            TextButton(
                              onPressed: () =>
                                  controller.skipImage(question.id),
                              child: const Text('Skip question'),
                            ),
                          _ => const SizedBox.shrink(),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
