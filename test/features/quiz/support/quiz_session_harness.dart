import 'package:flutter/material.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_state.dart';

/// Test-only interaction surface, not a production gameplay screen.
class QuizSessionHarness extends StatefulWidget {
  const QuizSessionHarness({super.key, required this.createController});
  final QuizSessionController Function() createController;
  @override
  State<QuizSessionHarness> createState() => _QuizSessionHarnessState();
}

class _QuizSessionHarnessState extends State<QuizSessionHarness>
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

  Future<void> cover() async {
    controller.setRouteVisible(false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Covering route')),
          body: TextButton(
            key: const Key('return'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Return'),
          ),
        ),
      ),
    );
    if (mounted) controller.setRouteVisible(true);
  }

  Future<void> confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave quiz?'),
        actions: [
          TextButton(
            key: const Key('stay'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            key: const Key('confirm-exit'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (mounted && exit == true) controller.abandon();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final state = controller.state;
      final index = switch (state) {
        QuizAnswering(:final index) || QuizFeedback(:final index) => index,
        _ => 0,
      };
      final remaining = switch (state) {
        QuizAnswering(:final remaining) ||
        QuizFeedback(:final remaining) => remaining,
        _ => null,
      };
      final seconds = remaining == null
          ? 0
          : (remaining.inMilliseconds / 1000).ceil();
      final timerLabel = controller.definition is DailyQuizDefinition
          ? 'Total time'
          : 'Question time';
      return Scaffold(
        appBar: AppBar(
          title: const Text('On This Day'),
          centerTitle: true,
          leading: IconButton(
            key: const Key('exit'),
            tooltip: 'Leave quiz',
            onPressed: confirmExit,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              key: const Key('cover'),
              tooltip: 'Cover route for test',
              onPressed: cover,
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
        body: Column(
          children: [
            if (state is QuizAnswering || state is QuizFeedback)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${index + 1} / ${controller.definition.questionCount}',
                        ),
                        if (remaining != null)
                          Text(
                            '$timerLabel ${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                            key: const Key('timer'),
                          ),
                      ],
                    ),
                    LinearProgressIndicator(
                      value: (index + 1) / controller.definition.questionCount,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: content(state),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: action(state),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget content(QuizSessionState state) => switch (state) {
    QuizPreparing() => const Text('Preparing'),
    QuizPreparationFailed() => const Text('Preparation failed'),
    QuizReady() => const Text('Ready'),
    QuizAbandoned() => const Text('Abandoned'),
    QuizInterrupted() => const Text('Interrupted'),
    QuizCompleted(:final result, :final delivery) => Column(
      children: [
        const Text('Completed'),
        Text('${result.correct} / ${result.total}'),
        Text(delivery.name),
      ],
    ),
    QuizFeedback(:final outcome) => Column(
      children: [
        Text(switch (outcome.kind) {
          QuestionOutcomeKind.correct => 'Correct',
          QuestionOutcomeKind.incorrect => 'Incorrect',
          QuestionOutcomeKind.timedOut => "Time's up",
          QuestionOutcomeKind.unanswered => 'Skipped',
        }),
        Text('Correct answer: ${correctAnswer(outcome.question)}'),
        if (controller.definition is QuickPlayQuizDefinition)
          Text(outcome.question.explanation),
      ],
    ),
    QuizAnswering() => answering(state),
  };

  String correctAnswer(QuizQuestion q) => switch (q) {
    ChoiceQuestion() =>
      q.options.firstWhere((o) => o.id == q.correctOptionId).text,
    ChronologicalOrderingQuestion() => q.correctOrderItemIds.join(', '),
  };

  Widget answering(QuizAnswering state) {
    final q = state.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(q.prompt, style: const TextStyle(fontSize: 24)),
        if (q is ImageIdentificationQuestion) Text(q.image.altText),
        if (q is ChoiceQuestion)
          for (final option in q.options)
            OutlinedButton(
              key: Key('option-${option.id}'),
              onPressed: () => controller.answerOption(q.id, option.id),
              child: Text(option.text),
            ),
        if (q is ChronologicalOrderingQuestion)
          for (var i = 0; i < state.orderingDraft.length; i++)
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.items
                        .firstWhere((v) => v.id == state.orderingDraft[i])
                        .text,
                  ),
                ),
                IconButton(
                  key: Key('up-${state.orderingDraft[i]}'),
                  tooltip: 'Move ${state.orderingDraft[i]} up',
                  onPressed: i == 0 ? null : () => move(state, i, i - 1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  key: Key('down-${state.orderingDraft[i]}'),
                  tooltip: 'Move ${state.orderingDraft[i]} down',
                  onPressed: i == 3 ? null : () => move(state, i, i + 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
      ],
    );
  }

  void move(QuizAnswering state, int from, int to) {
    final ids = state.orderingDraft.toList();
    final id = ids.removeAt(from);
    ids.insert(to, id);
    controller.updateOrderingDraft(state.question.id, ids);
  }

  Widget action(QuizSessionState state) => switch (state) {
    QuizPreparing() || QuizPreparationFailed() => FilledButton(
      key: const Key('prepare'),
      onPressed: controller.prepare,
      child: const Text('Prepare'),
    ),
    QuizReady() => FilledButton(
      key: const Key('start'),
      onPressed: controller.start,
      child: const Text('Start'),
    ),
    QuizFeedback(:final outcome) => FilledButton(
      key: const Key('continue'),
      onPressed: () => controller.continueQuiz(outcome.question.id),
      child: const Text('Continue'),
    ),
    QuizAnswering(:final question)
        when question is ChronologicalOrderingQuestion =>
      FilledButton(
        key: const Key('submit-order'),
        onPressed: () => controller.submitOrder(question.id),
        child: const Text('Submit order'),
      ),
    QuizAnswering(:final question)
        when question is ImageIdentificationQuestion =>
      TextButton(
        key: const Key('skip'),
        onPressed: () => controller.skipImage(question.id),
        child: const Text('Skip question'),
      ),
    _ => const SizedBox.shrink(),
  };
}
