import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_theme.dart';
import '../application/daily_challenge_status.dart';
import '../application/quiz_completion_coordinator.dart';
import '../application/quiz_session_launch_request.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_result.dart';
import '../domain/quiz_repository.dart';
import 'daily_challenge_setup_controller.dart';
import 'quiz_hub_controller.dart';
import 'widgets/quiz_design.dart';
import 'widgets/quiz_question_count_selector.dart';

/// Quiz's root content inside the shared Today/Quiz shell.
///
/// When [createDailySetup] and [onLaunchDaily] are supplied, an available
/// Daily is configured on the Hub with the Daily Setup controller's rules and
/// handed straight to the Ready route. A Daily that already has a result, or
/// has no attempt available, keeps the Daily Setup entry instead.
final class QuizHubScreen extends StatefulWidget {
  const QuizHubScreen({
    super.key,
    required this.repository,
    required this.onOpenDaily,
    required this.onOpenQuickPlay,
    this.dailyStatus,
    this.onReviewDailyResult,
    this.createDailySetup,
    this.onLaunchDaily,
    this.onDailyStatusResolved,
    this.embedded = false,
  });

  final QuizRepository repository;
  final ValueChanged<QuizCatalog> onOpenDaily;
  final ValueChanged<QuizCatalog> onOpenQuickPlay;
  final DailyChallengeStatus? dailyStatus;
  final ValueChanged<QuizResult>? onReviewDailyResult;
  final DailyChallengeSetupController Function(QuizAvailability availability)?
  createDailySetup;
  final ValueChanged<QuizSessionLaunchRequest>? onLaunchDaily;
  final ValueChanged<DailyChallengeStatus>? onDailyStatusResolved;
  final bool embedded;

  @override
  State<QuizHubScreen> createState() => _QuizHubScreenState();
}

class _QuizHubScreenState extends State<QuizHubScreen> {
  late final QuizHubController _controller;
  DailyChallengeSetupController? _daily;
  QuizCatalog? _dailyCatalog;
  DailyChallengeStatus? _lastDailyStatus;
  bool _dailyHandingOff = false;

  bool get _launchesDailyInline =>
      widget.createDailySetup != null && widget.onLaunchDaily != null;

  @override
  void initState() {
    super.initState();
    _controller = QuizHubController(widget.repository)
      ..addListener(_syncDailySetup);
    if (widget.dailyStatus case final status?) {
      _controller.updateDailyStatus(status);
    }
    _controller.load();
  }

  /// Creates one Daily controller per loaded catalog; status-only Hub updates
  /// reuse the same catalog and never request the Daily again.
  void _syncDailySetup() {
    final factory = widget.createDailySetup;
    final state = _controller.state;
    if (!_launchesDailyInline ||
        factory == null ||
        state is! QuizHubLoaded ||
        identical(state.catalog, _dailyCatalog)) {
      return;
    }
    _disposeDaily();
    _dailyCatalog = state.catalog;
    final daily = factory(state.catalog.mixed)
      ..addListener(_publishDailyStatus);
    _daily = daily;
    daily.load();
  }

  void _publishDailyStatus() {
    final data = switch (_daily?.state) {
      DailyChallengeSetupReady(:final data) => data,
      DailyChallengeSetupStarting(:final data) => data,
      _ => null,
    };
    if (data == null || identical(data.status, _lastDailyStatus)) return;
    _lastDailyStatus = data.status;
    widget.onDailyStatusResolved?.call(data.status);
  }

  Future<void> _startDaily() async {
    final daily = _daily;
    if (daily == null || _dailyHandingOff) return;
    setState(() => _dailyHandingOff = true);
    try {
      final launch = await daily.start();
      // A result recorded meanwhile turns the refreshed status into practice;
      // the Hub then shows that status rather than launching unannounced.
      if (mounted &&
          identical(daily, _daily) &&
          launch != null &&
          launch.saveIntent == QuizSaveIntent.claimDailyIfAbsent) {
        widget.onLaunchDaily?.call(launch);
      }
    } finally {
      if (mounted) setState(() => _dailyHandingOff = false);
    }
  }

  void _disposeDaily() {
    _daily
      ?..removeListener(_publishDailyStatus)
      ..dispose();
    _daily = null;
    _dailyCatalog = null;
    _lastDailyStatus = null;
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
    _disposeDaily();
    _controller
      ..removeListener(_syncDailySetup)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
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
          dailyLaunch: _daily == null
              ? null
              : _DailyLaunch(
                  controller: _daily!,
                  handingOff: _dailyHandingOff,
                  onStart: _startDaily,
                  // Daily availability comes from the catalog, so an
                  // unavailable Daily recovers by reloading it.
                  onRefreshAvailability: _controller.load,
                ),
        ),
      },
    );
    return widget.embedded ? body : Scaffold(appBar: _masthead(), body: body);
  }
}

AppBar _masthead() => AppBar(
  automaticallyImplyLeading: false,
  toolbarHeight: 56,
  title: const Text('On This Day', style: AppText.masthead),
  bottom: const PreferredSize(
    preferredSize: Size.fromHeight(1),
    child: Divider(height: 1, color: AppColors.paleStone),
  ),
);

class _HubContent extends StatelessWidget {
  const _HubContent({
    required this.catalog,
    required this.dailyStatus,
    required this.onOpenDaily,
    required this.onOpenQuickPlay,
    required this.onReviewDailyResult,
    required this.dailyLaunch,
  });

  final QuizCatalog catalog;
  final DailyChallengeStatus? dailyStatus;
  final ValueChanged<QuizCatalog> onOpenDaily;
  final ValueChanged<QuizCatalog> onOpenQuickPlay;
  final ValueChanged<QuizResult>? onReviewDailyResult;
  final _DailyLaunch? dailyLaunch;

  @override
  Widget build(BuildContext context) {
    final launch = dailyLaunch;
    if (launch == null) return _content(context, dailyStatus, null);
    return ListenableBuilder(
      listenable: launch.controller,
      builder: (context, _) {
        final state = launch.controller.state;
        final resolved = switch (state) {
          DailyChallengeSetupReady(:final data) => data.status,
          DailyChallengeSetupStarting(:final data) => data.status,
          _ => null,
        };
        final blocked =
            dailyStatus?.blocksOfficialClaim == true ||
            resolved?.blocksOfficialClaim == true;
        return _content(
          context,
          dailyStatus ?? resolved,
          blocked
              ? null
              : _DailyLaunchPanel(
                  state: state,
                  handingOff: launch.handingOff,
                  onCountSelected: launch.controller.selectQuestionCount,
                  onStart: launch.onStart,
                  onRetry: launch.controller.load,
                  onRefreshAvailability: launch.onRefreshAvailability,
                ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    DailyChallengeStatus? dailyStatus,
    Widget? dailyAction,
  ) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      Semantics(
        header: true,
        child: Text('Quiz', style: Theme.of(context).textTheme.displaySmall),
      ),
      const SizedBox(height: 6),
      Text(
        'Choose today\'s challenge or build a quick round.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.bodySoft),
      ),
      const SizedBox(height: 20),
      _ModeSurface(
        eyebrow: 'Daily Challenge',
        eyebrowIcon: Icons.calendar_today_outlined,
        badge: _dailyBadge(context, dailyStatus),
        title: dailyStatus?.displayDate ?? 'Today\'s challenge',
        description: _dailyDescription(dailyStatus),
        status: _DailyStatusLine(
          status: dailyStatus,
          onReview: onReviewDailyResult,
        ),
        actionLabel: dailyStatus?.hasConfirmedOfficial == true
            ? 'Practice again'
            : 'Set up today\'s challenge',
        actionIcon: Icons.arrow_forward,
        onPressed: () => onOpenDaily(catalog),
        outlinedAction: dailyStatus?.hasConfirmedOfficial == true,
        action: dailyAction,
      ),
      const SizedBox(height: 14),
      _ModeSurface(
        eyebrow: 'Quick Play',
        eyebrowIcon: Icons.tune,
        title: 'Practice any time',
        description: _quickDescription(catalog),
        actionLabel: 'Set up a quick round',
        actionIcon: Icons.tune,
        outlinedAction: true,
        onPressed: () => onOpenQuickPlay(catalog),
      ),
    ],
  );

  Widget? _dailyBadge(BuildContext context, DailyChallengeStatus? status) {
    if (status == null) return null;
    final done = status.hasConfirmedOfficial;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (done) ...[
          const Icon(
            Icons.check_circle,
            size: 18,
            color: AppColors.archivalCobalt,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          done ? 'Done' : 'Not played yet',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: done ? AppColors.deepInk : AppColors.mutedGray,
            fontWeight: done ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }

  String _dailyDescription(DailyChallengeStatus? status) {
    if (status?.hasConfirmedOfficial == true) {
      return 'Today\'s official score is saved.';
    }
    return 'A timed mix of history questions, refreshed daily.';
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
            'Today\'s score: ${official.result.correct} / ${official.result.total}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.archivalCobalt),
          ),
          const SizedBox(height: 10),
          QuizResultStrip(outcomes: official.result.outcomes),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.event_repeat_outlined,
                size: 18,
                color: AppColors.mutedGray,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Next challenge tomorrow.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (onReview != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onReview!(official.result),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Review answers'),
            ),
          ],
        ],
      );
    }
    final reservation = status?.reservation;
    if (reservation == null) return const SizedBox.shrink();
    final text = switch (reservation.status) {
      QuizCompletionSaveStatus.pending => 'Saving today\'s result…',
      QuizCompletionSaveStatus.failed =>
        'Today\'s result has not been saved yet. Another attempt will count as practice.',
      QuizCompletionSaveStatus.saved => 'Today\'s result is already recorded.',
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
    required this.eyebrowIcon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
    this.badge,
    this.status,
    this.action,
    this.outlinedAction = false,
  });

  final String eyebrow;
  final IconData eyebrowIcon;
  final Widget? badge;
  final String title;
  final String description;
  final Widget? status;

  /// Replaces the default action button when present.
  final Widget? action;
  final String actionLabel;
  final IconData actionIcon;
  final bool outlinedAction;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(eyebrowIcon, size: 18, color: AppColors.archivalCobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eyebrow,
                  style: AppText.eyebrow.copyWith(
                    fontSize: 14,
                    color: AppColors.archivalCobalt,
                  ),
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge!],
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            description,
            style: textTheme.bodyLarge?.copyWith(color: AppColors.bodySoft),
          ),
          if (status != null) ...[const SizedBox(height: 12), status!],
          const SizedBox(height: 16),
          if (action != null) ...[
            const FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Divider(color: AppColors.hairline),
            ),
            const SizedBox(height: 14),
            action!,
          ] else if (outlinedAction)
            OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(actionLabel),
            )
          else
            FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(actionIcon),
              iconAlignment: IconAlignment.end,
              label: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

final class _DailyLaunch {
  const _DailyLaunch({
    required this.controller,
    required this.handingOff,
    required this.onStart,
    required this.onRefreshAvailability,
  });
  final DailyChallengeSetupController controller;
  final bool handingOff;
  final VoidCallback onStart;
  final VoidCallback onRefreshAvailability;
}

/// The Daily count choice shown on the Hub while an official attempt is still
/// available. Its states come from [DailyChallengeSetupController].
class _DailyLaunchPanel extends StatelessWidget {
  const _DailyLaunchPanel({
    required this.state,
    required this.handingOff,
    required this.onCountSelected,
    required this.onStart,
    required this.onRetry,
    required this.onRefreshAvailability,
  });
  final DailyChallengeSetupState state;
  final bool handingOff;
  final ValueChanged<int> onCountSelected;
  final VoidCallback onStart;
  final VoidCallback onRetry;
  final VoidCallback onRefreshAvailability;

  @override
  Widget build(BuildContext context) => switch (state) {
    DailyChallengeSetupLoading() => Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Getting today\'s challenge…',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedGray),
            ),
          ),
        ],
      ),
    ),
    DailyChallengeSetupEmpty() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Daily Challenge is not available right now.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedGray),
        ),
        const SizedBox(height: 12),
        _retryButton(onRefreshAvailability),
      ],
    ),
    DailyChallengeSetupFailure(:final message, :final data) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        if (data != null) ...[
          const SizedBox(height: 6),
          Text(
            'The challenge is for ${data.status.displayDate}. Retry to check whether a result is already saved.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedGray),
          ),
        ],
        const SizedBox(height: 12),
        _retryButton(onRetry),
      ],
    ),
    DailyChallengeSetupReady(:final data) => _countChoice(
      context,
      data,
      starting: handingOff,
    ),
    DailyChallengeSetupStarting(:final data) => _countChoice(
      context,
      data,
      starting: true,
    ),
  };

  Widget _retryButton(VoidCallback onPressed) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.refresh),
    label: const Text('Retry'),
  );

  Widget _countChoice(
    BuildContext context,
    DailyChallengeSetupData data, {
    required bool starting,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Your first completed result for this date is official. Later plays are practice.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedGray),
      ),
      const SizedBox(height: 14),
      Text('Question count', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      QuizQuestionCountSelector(
        selected: data.selectedQuestionCount,
        supported: data.availability.supportedQuestionCounts.toSet(),
        detailFor: (count) {
          final duration = data.durationFor(count);
          return duration == null ? null : '${duration.inMinutes} min';
        },
        onSelected: starting ? null : onCountSelected,
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: starting || !data.selectedCountIsSupported ? null : onStart,
        icon: const Icon(Icons.arrow_forward),
        label: Text(
          starting
              ? 'Getting your challenge ready…'
              : 'Get ready for ${data.selectedQuestionCount} questions',
        ),
      ),
    ],
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
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
