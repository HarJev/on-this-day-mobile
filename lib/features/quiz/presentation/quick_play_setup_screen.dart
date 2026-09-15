import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../application/quiz_completion_id_generator.dart';
import '../application/quiz_session_launch_request.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_repository.dart';
import '../domain/quiz_result_store.dart';
import '../domain/quiz_rules.dart';
import 'quick_play_setup_controller.dart';

final class QuickPlaySetupScreen extends StatefulWidget {
  const QuickPlaySetupScreen({
    super.key,
    required this.repository,
    required this.resultStore,
    required this.completionIdGenerator,
    required this.catalog,
    required this.onLaunch,
    required this.onBack,
  });

  final QuizRepository repository;
  final QuizResultStore resultStore;
  final QuizCompletionIdGenerator completionIdGenerator;
  final QuizCatalog catalog;
  final ValueChanged<QuizSessionLaunchRequest> onLaunch;
  final VoidCallback onBack;

  @override
  State<QuickPlaySetupScreen> createState() => _QuickPlaySetupScreenState();
}

class _QuickPlaySetupScreenState extends State<QuickPlaySetupScreen> {
  late final QuickPlaySetupController _controller;
  bool _handingOff = false;

  @override
  void initState() {
    super.initState();
    _controller = QuickPlaySetupController(
      repository: widget.repository,
      resultStore: widget.resultStore,
      completionIdGenerator: widget.completionIdGenerator,
      catalog: widget.catalog,
    )..load();
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

  Future<void> _chooseCollection(QuickPlaySetupData data) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => _CollectionSheet(
        catalog: data.catalog,
        selectedCollectionId: data.selectedCollectionId,
      ),
    );
    if (!mounted || selected == data.selectedCollectionId) return;
    _controller.selectCollection(selected);
  }

  @override
  void dispose() {
    _controller.dispose();
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
        QuickPlaySetupLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        QuickPlaySetupFailure(:final message) => _QuickMessage(
          message: message,
          onRetry: _controller.load,
          onBack: widget.onBack,
        ),
        QuickPlaySetupReady(:final data) => _QuickSetupBody(
          data: data,
          starting: _handingOff,
          onChooseCollection: () => _chooseCollection(data),
          onCountSelected: _controller.selectQuestionCount,
          onTimingChanged: _controller.setTimingEnabled,
          onStart: _start,
        ),
        QuickPlaySetupStarting(:final data) => _QuickSetupBody(
          data: data,
          starting: true,
          onChooseCollection: () {},
          onCountSelected: _controller.selectQuestionCount,
          onTimingChanged: _controller.setTimingEnabled,
          onStart: _start,
        ),
      },
    ),
  );
}

class _QuickSetupBody extends StatelessWidget {
  const _QuickSetupBody({
    required this.data,
    required this.starting,
    required this.onChooseCollection,
    required this.onCountSelected,
    required this.onTimingChanged,
    required this.onStart,
  });
  final QuickPlaySetupData data;
  final bool starting;
  final VoidCallback onChooseCollection;
  final ValueChanged<int> onCountSelected;
  final ValueChanged<bool> onTimingChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
    children: [
      Text(
        'Quick Play',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontFamily: 'Georgia',
          fontFamilyFallback: const ['Times New Roman', 'serif'],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Choose a collection, length, and timing preference.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 24),
      Text('Collection', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: starting ? null : onChooseCollection,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(52),
        ),
        icon: const Icon(Icons.collections_bookmark_outlined),
        label: Text(data.selectedCollection?.name ?? 'Mixed'),
      ),
      const SizedBox(height: 24),
      Text('Questions', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      _QuickCountSelector(
        selected: data.selectedQuestionCount,
        supported: data.availability.supportedQuestionCounts.toSet(),
        onSelected: starting ? null : onCountSelected,
      ),
      if (!data.selectedCountIsSupported) ...[
        const SizedBox(height: 8),
        Text(
          'Choose a supported question count for this collection.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
      const SizedBox(height: 24),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Timed questions'),
        subtitle: Text(
          data.timingEnabled
              ? 'Each question uses the backend time limit.'
              : 'Questions have no countdown.',
        ),
        value: data.timingEnabled,
        onChanged: starting || data.preferenceSaving ? null : onTimingChanged,
      ),
      if (data.preferenceError case final message?)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed:
            starting || data.preferenceSaving || !data.selectedCountIsSupported
            ? null
            : onStart,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(starting ? 'Starting…' : 'Start Quick Play'),
      ),
    ],
  );
}

class _QuickCountSelector extends StatelessWidget {
  const _QuickCountSelector({
    required this.selected,
    required this.supported,
    required this.onSelected,
  });
  final int selected;
  final Set<int> supported;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final count in const [5, 10, 20])
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: count == 20 ? 0 : 8),
            child: OutlinedButton(
              onPressed: onSelected == null || !supported.contains(count)
                  ? null
                  : () => onSelected!(count),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                backgroundColor: selected == count && supported.contains(count)
                    ? AppColors.softIvory
                    : Colors.transparent,
                side: BorderSide(
                  color: selected == count && !supported.contains(count)
                      ? Theme.of(context).colorScheme.error
                      : selected == count
                      ? AppColors.archivalCobalt
                      : AppColors.paleStone,
                  width: selected == count ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$count'),
                  if (!supported.contains(count)) const Text('Unavailable'),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _CollectionSheet extends StatelessWidget {
  const _CollectionSheet({
    required this.catalog,
    required this.selectedCollectionId,
  });
  final QuizCatalog catalog;
  final String? selectedCollectionId;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          'Choose collection',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mixed'),
          trailing: selectedCollectionId == null
              ? const Icon(Icons.check)
              : null,
          onTap: () => Navigator.pop<String?>(context, null),
        ),
        for (final group in QuizCollectionGroup.values) ...[
          if (catalog.collections.any((item) => item.group == group)) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                _groupLabel(group),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.archivalCobalt,
                ),
              ),
            ),
            for (final collection in catalog.collections.where(
              (item) => item.group == group,
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(collection.name),
                subtitle: Text(
                  '${collection.availability.publishedQuestionCount} published questions',
                ),
                trailing: selectedCollectionId == collection.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop<String?>(context, collection.id),
              ),
          ],
        ],
      ],
    ),
  );

  String _groupLabel(QuizCollectionGroup group) => switch (group) {
    QuizCollectionGroup.topic => 'Topic',
    QuizCollectionGroup.historicalPeriod => 'Historical period',
    QuizCollectionGroup.civilization => 'Civilization',
    QuizCollectionGroup.conflictOrMovement => 'Conflict or movement',
  };
}

class _QuickMessage extends StatelessWidget {
  const _QuickMessage({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });
  final String message;
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
