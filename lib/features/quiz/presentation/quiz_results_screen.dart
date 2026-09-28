import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_theme.dart';
import '../application/quiz_completion_coordinator.dart';
import '../domain/question_outcome.dart';
import '../domain/quiz_definition.dart';
import '../domain/quiz_result.dart';
import 'widgets/quiz_design.dart';

/// Observes a completion that was already registered by gameplay. It never
/// starts a save itself: Results only renders coordinator-owned state or retries
/// the exact frozen completion after a failure.
final class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({
    super.key,
    required this.coordinator,
    required this.completionId,
    required this.onReview,
    required this.onDone,
  });

  final QuizCompletionCoordinator coordinator;
  final String completionId;
  final ValueChanged<QuizResult> onReview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: coordinator,
    builder: (context, _) {
      final state = coordinator.stateFor(completionId);
      if (state == null) return _UnavailableResult(onDone: onDone);
      return _ResultContent(
        key: ValueKey('results-$completionId'),
        coordinator: coordinator,
        state: state,
        onReview: onReview,
        onDone: onDone,
      );
    },
  );
}

final class _UnavailableResult extends StatelessWidget {
  const _UnavailableResult({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _appBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32),
            const SizedBox(height: 12),
            Text(
              'This completed result is unavailable.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _ResultContent extends StatefulWidget {
  const _ResultContent({
    super.key,
    required this.coordinator,
    required this.state,
    required this.onReview,
    required this.onDone,
  });

  final QuizCompletionCoordinator coordinator;
  final QuizCompletionSaveState state;
  final ValueChanged<QuizResult> onReview;
  final VoidCallback onDone;

  @override
  State<_ResultContent> createState() => _ResultContentState();
}

final class _ResultContentState extends State<_ResultContent> {
  bool retryStarting = false;

  Future<void> retry() async {
    if (retryStarting ||
        widget.state.status == QuizCompletionSaveStatus.pending) {
      return;
    }
    setState(() => retryStarting = true);
    try {
      await widget.coordinator.retry(
        widget.state.completion.result.completionId,
      );
    } catch (_) {
      // The coordinator retains a safe failed state and the diagnostic cause.
    } finally {
      if (mounted) setState(() => retryStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.state.completion.result;
    final daily = result.definition is DailyQuizDefinition;
    final revisit = result.outcomes.indexWhere(
      (o) =>
          o.kind == QuestionOutcomeKind.incorrect ||
          o.kind == QuestionOutcomeKind.timedOut,
    );
    return Scaffold(
      appBar: _appBar(result),
      body: ListView(
        key: const PageStorageKey('quiz-results-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _ScoreSummary(result: result),
          const SizedBox(height: 16),
          QuizResultStrip(
            outcomes: result.outcomes,
            showTypes: result.outcomes.length <= 5,
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.hairline),
          _Stats(result: result),
          const Divider(color: AppColors.hairline),
          const SizedBox(height: 4),
          _PersistenceStatus(
            state: widget.state,
            retryStarting: retryStarting,
            onRetry: retry,
          ),
          if (revisit >= 0) ...[
            const SizedBox(height: 12),
            _WorthRevisiting(
              number: revisit + 1,
              outcome: result.outcomes[revisit],
              onOpen: () => widget.onReview(result),
            ),
          ],
          if (daily) ...[const SizedBox(height: 12), const _TomorrowNote()],
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => widget.onReview(result),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review answers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDone,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.result});
  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detail = switch (result.definition) {
      DailyQuizDefinition(:final displayDate) => displayDate,
      QuickPlayQuizDefinition(:final selection) =>
        '${selection.displayName} · ${result.timingEnabled ? 'Timed' : 'Untimed'}',
    };
    return Semantics(
      container: true,
      label:
          '${result.correct} correct out of ${result.total}, ${result.percentage.round()} percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            detail,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedGray),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 16,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${result.correct}',
                      style: textTheme.displayLarge,
                    ),
                    TextSpan(
                      text: ' of ${result.total}',
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.mutedGray,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${result.percentage.round()}% correct',
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    color: AppColors.archivalCobalt,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.result});
  final QuizResult result;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Count(label: 'Answered', value: result.answered),
        ),
        Expanded(
          child: _Count(label: 'Correct', value: result.correct),
        ),
        Expanded(
          child: _Count(label: 'Unanswered', value: result.unanswered),
        ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedGray),
        ),
      ],
    ),
  );
}

/// The first missed question, with its explanation and a way into Review.
class _WorthRevisiting extends StatelessWidget {
  const _WorthRevisiting({
    required this.number,
    required this.outcome,
    required this.onOpen,
  });
  final int number;
  final QuestionOutcome outcome;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.softIvory,
        border: Border.all(color: AppColors.paleStone),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bookmark_border,
                size: 18,
                color: AppColors.mutedCopper,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Worth revisiting · Question $number',
                  style: AppText.eyebrow.copyWith(color: AppColors.copperDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            outcome.question.prompt,
            style: textTheme.titleLarge?.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 6),
          Text(
            outcome.question.explanation,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.bodySoft),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              child: const Text('Open in review'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TomorrowNote extends StatelessWidget {
  const _TomorrowNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.pressedFill,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.event_repeat_outlined,
          size: 20,
          color: AppColors.mutedGray,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'A new Daily Challenge arrives tomorrow.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _PersistenceStatus extends StatelessWidget {
  const _PersistenceStatus({
    required this.state,
    required this.retryStarting,
    required this.onRetry,
  });
  final QuizCompletionSaveState state;
  final bool retryStarting;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final saved = state.storedResult;
    final text = switch (status) {
      QuizCompletionSaveStatus.pending => 'Saving result…',
      QuizCompletionSaveStatus.failed => 'Result not saved',
      QuizCompletionSaveStatus.saved
          when saved?.classification == QuizSavedClassification.official =>
        'Official Daily result',
      QuizCompletionSaveStatus.saved
          when saved?.classification == QuizSavedClassification.practice &&
              state.requestedIntent == QuizSaveIntent.claimDailyIfAbsent =>
        'Practice result. Today\'s official score was already recorded.',
      QuizCompletionSaveStatus.saved
          when saved?.classification == QuizSavedClassification.practice =>
        'Practice result',
      QuizCompletionSaveStatus.saved => 'Quick Play result',
    };
    final icon = switch (status) {
      QuizCompletionSaveStatus.pending => Icons.sync,
      QuizCompletionSaveStatus.failed => Icons.cloud_off_outlined,
      QuizCompletionSaveStatus.saved
          when saved?.classification == QuizSavedClassification.official =>
        Icons.verified,
      QuizCompletionSaveStatus.saved => Icons.check_circle_outline,
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: AppColors.archivalCobalt),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (status == QuizCompletionSaveStatus.failed) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: retryStarting ? null : onRetry,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(retryStarting ? 'Retrying…' : 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

AppBar _appBar([QuizResult? result]) => AppBar(
  title: Text(switch (result?.definition) {
    DailyQuizDefinition() => 'Daily Challenge',
    QuickPlayQuizDefinition() => 'Quick Play',
    null => 'Results',
  }),
);
