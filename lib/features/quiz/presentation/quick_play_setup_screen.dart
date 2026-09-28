import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_theme.dart';
import '../application/quiz_completion_id_generator.dart';
import '../application/quiz_session_launch_request.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_repository.dart';
import '../domain/quiz_result_store.dart';
import '../domain/quiz_rules.dart';
import 'quick_play_setup_controller.dart';
import 'widgets/quiz_question_count_selector.dart';

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
    final selected = await showModalBottomSheet<({String? collectionId})>(
      context: context,
      showDragHandle: true,
      builder: (context) => _CollectionSheet(
        catalog: data.catalog,
        selectedCollectionId: data.selectedCollectionId,
      ),
    );
    if (!mounted ||
        selected == null ||
        selected.collectionId == data.selectedCollectionId) {
      return;
    }
    _controller.selectCollection(selected.collectionId);
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
      title: const Text('Quick Play'),
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = AppText.eyebrow.copyWith(color: AppColors.mutedGray);
    final collection = data.selectedCollection;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Build a round', style: textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Practice at your own pace. Results here don\'t affect your Daily.',
          style: textTheme.bodyLarge?.copyWith(color: AppColors.bodySoft),
        ),
        const SizedBox(height: 24),
        Text('Collection', style: label),
        const SizedBox(height: 8),
        _SetupCard(
          onTap: starting ? null : onChooseCollection,
          semanticsLabel:
              'Collection: ${collection?.name ?? 'Mixed'}. Change collection',
          child: Row(
            children: [
              const Icon(
                Icons.collections_bookmark_outlined,
                color: AppColors.mutedCopper,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection?.name ?? 'Mixed',
                      style: textTheme.titleMedium,
                    ),
                    Text(
                      collection == null
                          ? 'Questions from every collection'
                          : '${collection.availability.publishedQuestionCount} questions available',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Change',
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.archivalCobalt,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedGray),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Question count', style: label),
        const SizedBox(height: 8),
        QuizQuestionCountSelector(
          selected: data.selectedQuestionCount,
          supported: data.availability.supportedQuestionCounts.toSet(),
          onSelected: starting ? null : onCountSelected,
        ),
        if (!data.selectedCountIsSupported) ...[
          const SizedBox(height: 8),
          Text(
            'Choose a supported question count for this collection.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.copperDark),
          ),
        ],
        const SizedBox(height: 24),
        Text('Timer', style: label),
        const SizedBox(height: 8),
        _SetupCard(
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(
              Icons.timer_outlined,
              color: AppColors.mutedCopper,
            ),
            title: Text('Timed questions', style: textTheme.titleMedium),
            subtitle: Text(
              data.timingEnabled
                  ? 'Each question has its own countdown.'
                  : 'Questions have no countdown.',
              style: textTheme.bodySmall,
            ),
            value: data.timingEnabled,
            onChanged: starting || data.preferenceSaving
                ? null
                : onTimingChanged,
          ),
        ),
        if (data.preferenceError case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(color: AppColors.copperDark),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed:
              starting ||
                  data.preferenceSaving ||
                  !data.selectedCountIsSupported
              ? null
              : onStart,
          child: Text(
            starting
                ? 'Getting your quiz ready…'
                : 'Continue with ${data.selectedQuestionCount} questions',
          ),
        ),
      ],
    );
  }
}

/// An ivory settings card; tappable when [onTap] is given.
class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.child, this.onTap, this.semanticsLabel});
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: child,
    );
    return Material(
      color: AppColors.softIvory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.paleStone),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null && semanticsLabel == null
          ? content
          : Semantics(
              button: true,
              label: semanticsLabel,
              excludeSemantics: semanticsLabel != null,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
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
          onTap: () => Navigator.pop(context, (collectionId: null)),
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
                  '${collection.availability.publishedQuestionCount} questions available',
                ),
                trailing: selectedCollectionId == collection.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () =>
                    Navigator.pop(context, (collectionId: collection.id)),
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onBack, child: const Text('Back')),
        ],
      ),
    ),
  );
}
