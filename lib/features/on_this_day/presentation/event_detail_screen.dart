import 'package:flutter/material.dart';

import '../../../core/images/cached_optional_image_loader.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/app_theme.dart';
import '../../../core/navigation/source_launcher.dart';
import '../../../core/notifications/notification_prompt_coordinator.dart';
import '../domain/event_source.dart';
import '../domain/historical_event.dart';
import '../domain/on_this_day_repository.dart';
import 'event_detail_controller.dart';
import 'widgets/event_image_credit.dart';
import 'widgets/notification_pre_prompt.dart';
import 'widgets/optional_event_image.dart';
import 'widgets/source_row.dart';
import 'widgets/today_states.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.repository,
    required this.eventId,
    required this.sourceLauncher,
    this.imageLoader,
    this.notificationPrompt,
    this.onTestWhatYouLearned,
  }) : assert(eventId != '');

  final OnThisDayRepository repository;
  final String eventId;
  final SourceLauncher sourceLauncher;
  final OptionalImageLoader? imageLoader;

  /// When provided, a notification pre-prompt may appear after the sources of
  /// a successfully loaded event.
  final NotificationPromptCoordinator? notificationPrompt;

  /// When provided, the article ends with a compact link into the quiz.
  final VoidCallback? onTestWhatYouLearned;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EventDetailController(
      repository: widget.repository,
      eventId: widget.eventId,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.loadEvent();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return switch (state) {
          EventDetailLoading() => const _DetailScaffold(body: _LoadingState()),
          EventDetailLoaded(:final event) => _DetailScaffold(
            body: _LoadedState(
              event: event,
              onSourceSelected: _openSource,
              imageLoader: widget.imageLoader,
              sourceLauncher: widget.sourceLauncher,
              notificationPrompt: widget.notificationPrompt,
              onTestWhatYouLearned: widget.onTestWhatYouLearned,
            ),
          ),
          EventDetailUnavailable(:final message) => _DetailScaffold(
            body: _MessageState(
              icon: Icons.event_busy_outlined,
              message: message,
              help: 'Please try again in a little while.',
              onRetry: _controller.retry,
            ),
          ),
          EventDetailError(:final message) => _DetailScaffold(
            body: _MessageState(
              icon: Icons.error_outline,
              message: message,
              help: 'Check your connection and try again.',
              onRetry: _controller.retry,
            ),
          ),
        };
      },
    );
  }

  Future<void> _openSource(EventSource source) async {
    final opened = await widget.sourceLauncher.open(source.url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open source.')));
    }
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 56,
        leadingWidth: 56,
        titleSpacing: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              )
            : const SizedBox.shrink(),
        title: Text('On This Day', style: AppText.navTitle),
        actions: const [SizedBox(width: 56)],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(
            color: AppColors.paleStone,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _LoadedState extends StatefulWidget {
  const _LoadedState({
    required this.event,
    required this.onSourceSelected,
    required this.sourceLauncher,
    this.imageLoader,
    this.notificationPrompt,
    this.onTestWhatYouLearned,
  });

  final HistoricalEvent event;
  final ValueChanged<EventSource> onSourceSelected;
  final SourceLauncher sourceLauncher;
  final OptionalImageLoader? imageLoader;
  final NotificationPromptCoordinator? notificationPrompt;
  final VoidCallback? onTestWhatYouLearned;

  @override
  State<_LoadedState> createState() => _LoadedStateState();
}

class _LoadedStateState extends State<_LoadedState> {
  final ScrollController _scrollController = ScrollController();
  bool _reachedArticleEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_revealPromptAtArticleEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _revealPromptAtArticleEnd();
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_revealPromptAtArticleEnd)
      ..dispose();
    super.dispose();
  }

  /// Reveals the invitation once the reader is within this distance of the
  /// article's end (sources included), so it is laid out before they stop and
  /// they can keep scrolling into it.
  static const _revealWithin = 180.0;

  void _revealPromptAtArticleEnd() {
    if (_reachedArticleEnd || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _revealWithin) {
      return;
    }
    setState(() => _reachedArticleEnd = true);
  }

  @override
  Widget build(BuildContext context) {
    final notificationPrompt = widget.notificationPrompt;
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _ArticleSurface(
          event: widget.event,
          imageLoader: widget.imageLoader,
          sourceLauncher: widget.sourceLauncher,
        ),
        if (widget.event.sources.isNotEmpty) ...[
          const SizedBox(height: 24),
          SourcesDisclosure(
            sources: widget.event.sources,
            onSourceSelected: widget.onSourceSelected,
          ),
        ],
        if (widget.onTestWhatYouLearned case final onTest?)
          _TestWhatYouLearnedLink(onTap: onTest),
        if (_reachedArticleEnd && notificationPrompt != null)
          NotificationPrePrompt(coordinator: notificationPrompt),
      ],
    );
  }
}

class _TestWhatYouLearnedLink extends StatelessWidget {
  const _TestWhatYouLearnedLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Semantics(
        button: true,
        label: 'Test what you learned. Opens the quiz',
        excludeSemantics: true,
        child: Material(
          color: AppColors.softIvory,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.paleStone),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.cobaltTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.quiz_outlined,
                        size: 20,
                        color: AppColors.archivalCobalt,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test what you learned',
                            style: textTheme.titleMedium,
                          ),
                          Text('Opens the quiz', style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.mutedGray),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleSurface extends StatelessWidget {
  const _ArticleSurface({
    required this.event,
    required this.sourceLauncher,
    this.imageLoader,
  });

  final HistoricalEvent event;
  final SourceLauncher sourceLauncher;
  final OptionalImageLoader? imageLoader;

  /// "August 22, 1485" reads as "August 22" beside the large year.
  static String dayLabelFor(HistoricalEvent event) {
    final suffix = ', ${event.year}';
    final date = event.historicalDate;
    return date.endsWith(suffix)
        ? date.substring(0, date.length - suffix.length)
        : date;
  }

  @override
  Widget build(BuildContext context) {
    final image = event.primaryImage;
    final loader = imageLoader;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: event.historicalDate,
          excludeSemantics: true,
          child: Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                event.year,
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.archivalCobalt,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  dayLabelFor(event),
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: AppColors.mutedGray,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0x8CA66A3F)),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(event.title, style: textTheme.headlineLarge),
        ),
        if (image != null && loader != null)
          OptionalEventImage(
            url: image.url,
            altText: image.altText,
            loader: loader,
            aspectRatio: null,
            padding: const EdgeInsets.only(top: 20),
            frame: (picture) => DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.paleStone),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: picture,
              ),
            ),
            caption: EventImageCredit(image: image, launcher: sourceLauncher),
          ),
        const SizedBox(height: 16),
        Text(
          event.description,
          style: textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.6),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  static const semanticsLabel = 'Loading event';

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: semanticsLabel,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: const [
          SkeletonBlock(width: 140, height: 22),
          SizedBox(height: 14),
          SkeletonBlock(height: 1),
          SizedBox(height: 14),
          SkeletonBlock(height: 30),
          SizedBox(height: 8),
          SkeletonBlock(width: 220, height: 30),
          SizedBox(height: 20),
          SkeletonBlock(height: 200),
          SizedBox(height: 18),
          SkeletonBlock(height: 16),
          SizedBox(height: 10),
          SkeletonBlock(height: 16),
          SizedBox(height: 10),
          SkeletonBlock(width: 180, height: 16),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.help,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final String help;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return TodayMessageCard(
      icon: icon,
      title: message,
      message: help,
      actionLabel: 'Try again',
      onActionPressed: onRetry,
      secondaryLabel: navigator.canPop() ? 'Back to Today' : null,
      onSecondaryPressed: navigator.canPop() ? navigator.maybePop : null,
    );
  }
}
