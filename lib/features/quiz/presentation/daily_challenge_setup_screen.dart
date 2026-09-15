import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/timezone_provider.dart';
import '../application/daily_challenge_status.dart';
import '../application/quiz_completion_coordinator.dart';
import '../application/quiz_completion_id_generator.dart';
import '../application/quiz_session_launch_request.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_repository.dart';
import '../domain/quiz_result_store.dart';
import 'daily_challenge_setup_controller.dart';

final class DailyChallengeSetupScreen extends StatefulWidget {
  const DailyChallengeSetupScreen({
    super.key,
    required this.repository,
    required this.timezoneProvider,
    required this.resultStore,
    required this.completionCoordinator,
    required this.completionIdGenerator,
    required this.availability,
    required this.onLaunch,
    required this.onStatusResolved,
    required this.onBack,
  });

  final QuizRepository repository;
  final TimezoneProvider timezoneProvider;
  final QuizResultStore resultStore;
  final QuizCompletionCoordinator completionCoordinator;
  final QuizCompletionIdGenerator completionIdGenerator;
  final QuizAvailability availability;
  final ValueChanged<QuizSessionLaunchRequest> onLaunch;
  final ValueChanged<DailyChallengeStatus> onStatusResolved;
  final VoidCallback onBack;

  @override
  State<DailyChallengeSetupScreen> createState() =>
      _DailyChallengeSetupScreenState();
}

class _DailyChallengeSetupScreenState extends State<DailyChallengeSetupScreen> {
  late final DailyChallengeSetupController _controller;
  DailyChallengeStatus? _lastStatus;
  bool _handingOff = false;

  @override
  void initState() {
    super.initState();
    _controller = DailyChallengeSetupController(
      repository: widget.repository,
      timezoneProvider: widget.timezoneProvider,
      resultStore: widget.resultStore,
      completionCoordinator: widget.completionCoordinator,
      completionIdGenerator: widget.completionIdGenerator,
      availability: widget.availability,
    )..addListener(_publishStatus);
    _controller.load();
  }

  void _publishStatus() {
    final data = switch (_controller.state) {
      DailyChallengeSetupReady(:final data) => data,
      DailyChallengeSetupStarting(:final data) => data,
      _ => null,
    };
    if (data == null || identical(data.status, _lastStatus)) return;
    _lastStatus = data.status;
    widget.onStatusResolved(data.status);
  }

  Future<void> _start() async {
    if (_handingOff) return;
    _handingOff = true;
    try {
      final launch = await _controller.start();
      if (mounted && launch != null) widget.onLaunch(launch);
    } finally {
      if (mounted) setState(() => _handingOff = false);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_publishStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text(
        'On This Day',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontFamilyFallback: ['Times New Roman', 'serif'],
          fontSize: 21,
        ),
      ),
    ),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => switch (_controller.state) {
        DailyChallengeSetupLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        DailyChallengeSetupEmpty() => _SetupMessage(
          message: 'Daily Challenge is not available right now.',
          onRetry: _controller.load,
          onBack: widget.onBack,
        ),
        DailyChallengeSetupFailure(:final message, :final data) => _SetupMessage(
          message: message,
          detail: data == null
              ? null
              : 'The backend date is ${data.status.displayDate}. Retry to check your Daily result for that date.',
          onRetry: _controller.load,
          onBack: widget.onBack,
        ),
        DailyChallengeSetupReady(:final data) => _DailySetupBody(
          data: data,
          starting: _handingOff,
          onCountSelected: _controller.selectQuestionCount,
          onStart: _start,
        ),
        DailyChallengeSetupStarting(:final data) => _DailySetupBody(
          data: data,
          starting: true,
          onCountSelected: _controller.selectQuestionCount,
          onStart: _start,
        ),
      },
    ),
  );
}

class _DailySetupBody extends StatelessWidget {
  const _DailySetupBody({
    required this.data,
    required this.starting,
    required this.onCountSelected,
    required this.onStart,
  });
  final DailyChallengeSetupData data;
  final bool starting;
  final ValueChanged<int> onCountSelected;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
    children: [
      Text(
        'Daily Challenge',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontFamily: 'Georgia',
          fontFamilyFallback: const ['Times New Roman', 'serif'],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        data.status.displayDate,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 20),
      _DailyPolicy(status: data.status),
      const SizedBox(height: 24),
      Text('Choose a length', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      _QuestionCountSelector(
        selected: data.selectedQuestionCount,
        supported: data.availability.supportedQuestionCounts.toSet(),
        durationFor: data.durationFor,
        onSelected: starting ? null : onCountSelected,
      ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: starting || !data.selectedCountIsSupported ? null : onStart,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(
          starting
              ? 'Starting…'
              : 'Start Challenge (${data.selectedQuestionCount} Questions)',
        ),
      ),
    ],
  );
}

class _DailyPolicy extends StatelessWidget {
  const _DailyPolicy({required this.status});
  final DailyChallengeStatus status;

  @override
  Widget build(BuildContext context) {
    final text = status.hasConfirmedOfficial
        ? 'Your official result is saved. A new play for this date is practice.'
        : status.reservation != null
        ? 'A completed result already reserves this date while the app is open. A new play is practice.'
        : 'Your first completed result for this backend date is official. Later plays are practice.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softIvory,
        border: Border.all(color: AppColors.paleStone),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _QuestionCountSelector extends StatelessWidget {
  const _QuestionCountSelector({
    required this.selected,
    required this.supported,
    required this.durationFor,
    required this.onSelected,
  });
  final int selected;
  final Set<int> supported;
  final Duration? Function(int) durationFor;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final count in const [5, 10, 20])
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: count == 20 ? 0 : 8),
            child: _CountButton(
              count: count,
              selected: selected == count,
              supported: supported.contains(count),
              duration: durationFor(count),
              onPressed: onSelected == null || !supported.contains(count)
                  ? null
                  : () => onSelected!(count),
            ),
          ),
        ),
    ],
  );
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.count,
    required this.selected,
    required this.supported,
    required this.duration,
    required this.onPressed,
  });
  final int count;
  final bool selected;
  final bool supported;
  final Duration? duration;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: '$count questions',
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(92),
        backgroundColor: selected && supported
            ? AppColors.softIvory
            : Colors.transparent,
        side: BorderSide(
          color: selected && !supported
              ? Theme.of(context).colorScheme.error
              : selected
              ? AppColors.archivalCobalt
              : AppColors.paleStone,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: Theme.of(context).textTheme.headlineSmall),
          Text('Questions'),
          if (duration != null)
            Text(
              _minutes(duration!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (!supported) const Text('Unavailable'),
        ],
      ),
    ),
  );

  String _minutes(Duration duration) => '${duration.inMinutes} min';
}

class _SetupMessage extends StatelessWidget {
  const _SetupMessage({
    required this.message,
    required this.onRetry,
    required this.onBack,
    this.detail,
  });
  final String message;
  final String? detail;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Retry'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Back'),
          ),
        ],
      ),
    ),
  );
}
