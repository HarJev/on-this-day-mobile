import 'package:flutter/material.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/app_theme.dart';
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
import 'widgets/quiz_ordering_feedback.dart';
import 'widgets/quiz_ordering_question.dart';
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.jumpTo(0);
      });
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

  List<String>? orderingDraft(QuizSessionState state) => switch (state) {
    QuizAnswering(:final orderingDraft) => orderingDraft,
    QuizFeedback(:final orderingDraft) => orderingDraft,
    QuizCompleted(:final orderingDraft) => orderingDraft,
    _ => null,
  };
  Future<void> exit() async {
    if (exitPending || exited) return;
    exitPending = true;
    // Only an attempt in play has progress to lose; unstarted and terminal
    // states exit directly.
    final state = controller.state;
    final inPlay = state is QuizAnswering || state is QuizFeedback;
    final confirmed =
        !inPlay ||
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
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.copperDark,
                    ),
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
    final needsImage =
        q is ImageIdentificationQuestion && !resultsOpened && !exited;
    final missingImage =
        needsImage && controller.preparedImages?.contains(q.id) != true;
    final hasFooterAction =
        state is QuizFeedback ||
        state is QuizCompleted ||
        state is QuizAnswering &&
            (q is ImageIdentificationQuestion ||
                q is ChronologicalOrderingQuestion);
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
          title: Text(
            daily ? 'Daily Challenge' : 'Quick Play',
            style: AppText.navTitle,
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.hairline),
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
                    ? SafeArea(
                        top: false,
                        child: _SessionIntroduction(
                          definition: controller.definition,
                          timingEnabled: controller.timingEnabled,
                          state: state,
                          onStart: controller.start,
                          onRetry: controller.prepare,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (q is ChoiceQuestion) ...[
                            QuizChoiceQuestion(
                              question: q,
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
                                      creditAvailable: current.$3 != null,
                                    )
                                  : null,
                              onAnswer: (id) =>
                                  controller.answerOption(q.id, id),
                            ),
                            if (current.$3 != null)
                              QuizAnswerFeedback(
                                outcome: current.$3!,
                                daily: daily,
                                expired: expired,
                                launcher: widget.sourceLauncher,
                              ),
                          ],
                          if (q is ChronologicalOrderingQuestion) ...[
                            if (current.$3 == null)
                              QuizOrderingQuestion(
                                question: q,
                                headingFocus: headingFocus,
                                orderingDraft: orderingDraft(state)!,
                                onDraftChanged: (draft) =>
                                    controller.updateOrderingDraft(q.id, draft),
                              )
                            else ...[
                              _OrderingQuestionHeading(
                                question: q,
                                headingFocus: headingFocus,
                              ),
                              QuizOrderingFeedback(
                                outcome: current.$3!,
                                daily: daily,
                                expired: expired,
                                orderingDraft: orderingDraft(state),
                                launcher: widget.sourceLauncher,
                              ),
                            ],
                          ],
                        ],
                      ),
              ),
            ),
            if (hasFooterAction)
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.softIvory,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0F171A1F),
                      offset: Offset(0, -8),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (current?.$3 case final outcome?)
                          QuizFeedbackSummary(
                            outcome: outcome,
                            expired: expired,
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
                          QuizAnswering(:final question)
                              when question is ImageIdentificationQuestion &&
                                  !missingImage =>
                            TextButton(
                              onPressed: () =>
                                  controller.skipImage(question.id),
                              child: const Text('Skip question'),
                            ),
                          QuizAnswering(:final question)
                              when question is ChronologicalOrderingQuestion =>
                            FilledButton(
                              key: const Key('submit-order'),
                              onPressed: () =>
                                  controller.submitOrder(question.id),
                              child: const Text('Submit order'),
                            ),
                          _ => const SizedBox.shrink(),
                        },
                      ],
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

class _OrderingQuestionHeading extends StatelessWidget {
  const _OrderingQuestionHeading({
    required this.question,
    required this.headingFocus,
  });

  final ChronologicalOrderingQuestion question;
  final FocusNode headingFocus;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: headingFocus,
    child: Semantics(
      header: true,
      child: Text(
        question.prompt,
        key: const Key('quiz-heading'),
        style: AppText.questionPromptAnswered,
      ),
    ),
  );
}

class _SessionIntroduction extends StatelessWidget {
  const _SessionIntroduction({
    required this.definition,
    required this.timingEnabled,
    required this.state,
    required this.onStart,
    required this.onRetry,
  });

  final QuizDefinition definition;
  final bool timingEnabled;
  final QuizSessionState state;
  final VoidCallback onStart;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final daily = definition is DailyQuizDefinition;
    final preparing = state is QuizPreparing;
    final failed = state is QuizPreparationFailed;
    final imageFailed = switch (state) {
      QuizPreparationFailed(cause: QuizImagePreparationException()) => true,
      _ => false,
    };
    final interrupted = state is QuizInterrupted;
    final abandoned = state is QuizAbandoned;
    final imageCount = definition.questions
        .whereType<ImageIdentificationQuestion>()
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            daily ? 'Daily Challenge' : 'Quick Play',
            style: AppText.eyebrow.copyWith(color: AppColors.archivalCobalt),
          ),
          const SizedBox(height: 8),
          Text(
            interrupted
                ? 'Quiz interrupted'
                : abandoned
                ? 'Quiz ended'
                : imageFailed
                ? 'A picture couldn\'t load'
                : failed
                ? 'We couldn\'t prepare this quiz'
                : preparing
                ? daily
                      ? 'Preparing your challenge'
                      : 'Preparing your quiz'
                : daily
                ? 'Your challenge is ready'
                : 'Your quiz is ready',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          _SessionFact(
            icon: Icons.help_outline,
            label: '${definition.questionCount} questions',
          ),
          const SizedBox(height: 10),
          _SessionFact(
            icon: timingEnabled
                ? Icons.timer_outlined
                : Icons.timer_off_outlined,
            label: _timingLabel(),
          ),
          const SizedBox(height: 22),
          const FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.55,
            child: Divider(color: AppColors.mutedCopper),
          ),
          if (failed) ...[
            const SizedBox(height: 14),
            Text(
              imageFailed
                  ? 'One of the pictures for this quiz isn\'t available right '
                        'now. Nothing has been scored. Tap Retry to try again, '
                        'or use Back to return to Quiz.'
                  : 'Something went wrong while getting this quiz ready. '
                        'Nothing has been scored. Tap Retry to try again, or '
                        'use Back to return to Quiz.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (state is QuizReady || failed) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: failed ? onRetry : onStart,
              child: Text(
                failed
                    ? 'Retry'
                    : daily
                    ? 'Start challenge'
                    : 'Start quiz',
              ),
            ),
          ],
          if (preparing) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.hourglass_top,
                  size: 18,
                  color: AppColors.mutedGray,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    imageCount > 0
                        ? 'Loading pictures…'
                        : 'Getting everything in place…',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _timingLabel() {
    if (definition case DailyQuizDefinition(:final duration)) {
      return '${duration.inMinutes} minutes total';
    }
    if (!timingEnabled) return 'No countdown';
    final quick = definition as QuickPlayQuizDefinition;
    final seconds =
        quick.questionTimeLimits.values
            .map((duration) => duration.inSeconds)
            .toSet()
            .toList()
          ..sort();
    return seconds.length == 1
        ? '${seconds.single} seconds per question'
        : '${seconds.first}-${seconds.last} seconds per question';
  }
}

class _SessionFact extends StatelessWidget {
  const _SessionFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.archivalCobalt),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ),
    ],
  );
}
