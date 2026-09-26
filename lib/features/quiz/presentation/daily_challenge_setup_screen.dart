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
import 'widgets/quiz_question_count_selector.dart';

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
              : 'The challenge is for ${data.status.displayDate}. Retry to check whether a result is already saved.',
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
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
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
      const SizedBox(height: 16),
      _DailyPolicy(status: data.status),
      const SizedBox(height: 20),
      Text('Question count', style: Theme.of(context).textTheme.titleMedium),
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
      const SizedBox(height: 22),
      FilledButton(
        onPressed: starting || !data.selectedCountIsSupported ? null : onStart,
        child: Text(
          starting
              ? 'Getting your challenge ready…'
              : 'Continue with ${data.selectedQuestionCount} questions',
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
        ? 'A result is already recorded for this date. A new play is practice.'
        : 'Your first completed result for this date is official. Later plays are practice.';
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.mutedCopper, width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
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
