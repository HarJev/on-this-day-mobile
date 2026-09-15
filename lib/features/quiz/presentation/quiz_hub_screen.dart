import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../application/daily_challenge_status.dart';
import '../application/quiz_completion_coordinator.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_result.dart';
import '../domain/quiz_repository.dart';
import 'quiz_hub_controller.dart';

/// Quiz's root content. MQ10 will place it inside the shared Today/Quiz shell.
final class QuizHubScreen extends StatefulWidget {
  const QuizHubScreen({
    super.key,
    required this.repository,
    required this.onOpenDaily,
    required this.onOpenQuickPlay,
    this.dailyStatus,
    this.onReviewDailyResult,
  });

  final QuizRepository repository;
  final VoidCallback onOpenDaily;
  final VoidCallback onOpenQuickPlay;
  final DailyChallengeStatus? dailyStatus;
  final ValueChanged<QuizResult>? onReviewDailyResult;

  @override
  State<QuizHubScreen> createState() => _QuizHubScreenState();
}

class _QuizHubScreenState extends State<QuizHubScreen> {
  late final QuizHubController _controller;

  @override
  void initState() {
    super.initState();
    _controller = QuizHubController(widget.repository);
    if (widget.dailyStatus case final status?) {
      _controller.updateDailyStatus(status);
    }
    _controller.load();
  }

  @override
  void didUpdateWidget(covariant QuizHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.dailyStatus;
    if (status != oldWidget.dailyStatus && status != null) {
      _controller.updateDailyStatus(status);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _masthead(),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => switch (_controller.state) {
        QuizHubLoading() => const Center(child: CircularProgressIndicator()),
        QuizHubEmpty(:final dailyStatus) => _HubMessage(
          title: 'Quiz is not available yet.',
          dailyStatus: dailyStatus,
          onRetry: _controller.load,
        ),
        QuizHubFailure(:final message) => _HubMessage(
          title: message,
          onRetry: _controller.load,
        ),
        QuizHubLoaded(:final catalog, :final dailyStatus) => _HubContent(
          catalog: catalog,
          dailyStatus: dailyStatus,
          onOpenDaily: widget.onOpenDaily,
          onOpenQuickPlay: widget.onOpenQuickPlay,
          onReviewDailyResult: widget.onReviewDailyResult,
        ),
      },
    ),
  );
}

AppBar _masthead() => AppBar(
  automaticallyImplyLeading: false,
  title: const Text(
    'On This Day',
    style: TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: ['Times New Roman', 'serif'],
      fontSize: 21,
    ),
  ),
);

class _HubContent extends StatelessWidget {
  const _HubContent({
    required this.catalog,
    required this.dailyStatus,
    required this.onOpenDaily,
    required this.onOpenQuickPlay,
    required this.onReviewDailyResult,
  });

  final QuizCatalog catalog;
  final DailyChallengeStatus? dailyStatus;
  final VoidCallback onOpenDaily;
  final VoidCallback onOpenQuickPlay;
  final ValueChanged<QuizResult>? onReviewDailyResult;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
    children: [
      Text(
        'Quiz',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontFamily: 'Georgia',
          fontFamilyFallback: const ['Times New Roman', 'serif'],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'A short way to test what you know about history.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 24),
      _ModeSurface(
        eyebrow: 'DAILY CHALLENGE',
        title: dailyStatus?.displayDate ?? 'Daily Challenge',
        description: _dailyDescription(dailyStatus),
        status: _DailyStatusLine(
          status: dailyStatus,
          onReview: onReviewDailyResult,
        ),
        actionLabel: dailyStatus?.hasConfirmedOfficial == true
            ? 'Practice Daily Challenge'
            : 'Set up Daily Challenge',
        actionIcon: Icons.arrow_forward,
        onPressed: onOpenDaily,
      ),
      const SizedBox(height: 18),
      _ModeSurface(
        eyebrow: 'QUICK PLAY',
        title: 'Quick Play',
        description: _quickDescription(catalog),
        actionLabel: 'Configure Quick Play',
        actionIcon: Icons.tune,
        outlinedAction: true,
        onPressed: onOpenQuickPlay,
      ),
    ],
  );

  String _dailyDescription(DailyChallengeStatus? status) {
    if (status?.hasConfirmedOfficial == true) {
      return 'Your official result is saved for this backend date.';
    }
    return 'Choose a short timed challenge for the date returned by the backend.';
  }

  String _quickDescription(QuizCatalog catalog) {
    final count = catalog.collections.length;
    return count == 0
        ? 'Choose a timed or untimed mixed quiz.'
        : 'Choose Mixed or one of $count curated collections.';
  }
}

class _DailyStatusLine extends StatelessWidget {
  const _DailyStatusLine({required this.status, required this.onReview});
  final DailyChallengeStatus? status;
  final ValueChanged<QuizResult>? onReview;

  @override
  Widget build(BuildContext context) {
    final official = status?.confirmedOfficialResult;
    if (official != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Official result: ${official.result.correct} / ${official.result.total}',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: AppColors.archivalCobalt),
          ),
          if (onReview != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onReview!(official.result),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Review answers'),
              ),
            ),
        ],
      );
    }
    final reservation = status?.reservation;
    if (reservation == null) return const SizedBox.shrink();
    final text = switch (reservation.status) {
      QuizCompletionSaveStatus.pending => 'Saving today\'s completed result.',
      QuizCompletionSaveStatus.failed =>
        'Today\'s completed result is not saved. Another play is practice while the app stays open.',
      QuizCompletionSaveStatus.saved =>
        'A completed result already reserves this date.',
    };
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedGray),
    );
  }
}

class _ModeSurface extends StatelessWidget {
  const _ModeSurface({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
    this.status,
    this.outlinedAction = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? status;
  final String actionLabel;
  final IconData actionIcon;
  final bool outlinedAction;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
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
          eyebrow,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.archivalCobalt),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['Times New Roman', 'serif'],
          ),
        ),
        const SizedBox(height: 10),
        Text(description, style: Theme.of(context).textTheme.bodyLarge),
        if (status != null) ...[const SizedBox(height: 14), status!],
        const SizedBox(height: 18),
        if (outlinedAction)
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(actionIcon),
            label: Text(actionLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          )
        else
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(actionIcon),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
      ],
    ),
  );
}

class _HubMessage extends StatelessWidget {
  const _HubMessage({
    required this.title,
    required this.onRetry,
    this.dailyStatus,
  });
  final String title;
  final DailyChallengeStatus? dailyStatus;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, textAlign: TextAlign.center),
          if (dailyStatus?.hasConfirmedOfficial == true) ...[
            const SizedBox(height: 12),
            Text(
              'A confirmed Daily result remains available.',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
