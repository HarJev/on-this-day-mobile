import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../application/quiz_completion_coordinator.dart';
import '../domain/quiz_definition.dart';
import '../domain/quiz_result.dart';

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
    return Scaffold(
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('quiz-results-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResultHeading(result: result),
                  const SizedBox(height: 20),
                  _ScoreSummary(result: result),
                  const SizedBox(height: 16),
                  _PersistenceStatus(
                    state: widget.state,
                    retryStarting: retryStarting,
                    onRetry: retry,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () => widget.onReview(result),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Review answers'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: widget.onDone,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHeading extends StatelessWidget {
  const _ResultHeading({required this.result});
  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final definition = result.definition;
    final title = definition is DailyQuizDefinition
        ? 'Daily Challenge'
        : 'Quick Play';
    final detail = switch (definition) {
      DailyQuizDefinition(:final displayDate) => displayDate,
      QuickPlayQuizDefinition(:final selection) => selection.displayName,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.archivalCobalt),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['Times New Roman', 'serif'],
          ),
        ),
      ],
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.result});
  final QuizResult result;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        '${result.correct} correct out of ${result.total}, ${result.percentage.round()} percent',
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softIvory,
        border: Border.all(color: AppColors.paleStone),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${result.correct} / ${result.total}',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontFamily: 'Georgia',
              fontFamilyFallback: const ['Times New Roman', 'serif'],
            ),
          ),
          Text(
            '${result.percentage.round()}% correct',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.archivalCobalt),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.mutedCopper),
          ),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Count(label: 'Answered', value: result.answered),
              _Count(label: 'Correct', value: result.correct),
              _Count(label: 'Unanswered', value: result.unanswered),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Text('$label: $value');
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
        'Practice result. An earlier completed result owns this Daily date.',
      QuizCompletionSaveStatus.saved
          when saved?.classification == QuizSavedClassification.practice =>
        'Practice result',
      QuizCompletionSaveStatus.saved => 'Quick Play result',
    };
    final icon = switch (status) {
      QuizCompletionSaveStatus.pending => Icons.sync,
      QuizCompletionSaveStatus.failed => Icons.cloud_off_outlined,
      QuizCompletionSaveStatus.saved => Icons.check_circle_outline,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.paleStone)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.archivalCobalt),
                const SizedBox(width: 8),
                Expanded(child: Text(text)),
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

AppBar _appBar() => AppBar(
  title: const Text(
    'On This Day',
    style: TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: ['Times New Roman', 'serif'],
      fontSize: 21,
    ),
  ),
);
