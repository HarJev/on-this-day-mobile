import 'package:flutter/material.dart';

import '../../../core/images/cached_optional_image_loader.dart';
import '../../../core/config/app_colors.dart';
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

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.repository,
    required this.eventId,
    required this.sourceLauncher,
    this.imageLoader,
    this.notificationPrompt,
  }) : assert(eventId != '');

  final OnThisDayRepository repository;
  final String eventId;
  final SourceLauncher sourceLauncher;
  final OptionalImageLoader? imageLoader;

  /// When provided, a notification pre-prompt may appear after the sources of
  /// a successfully loaded event.
  final NotificationPromptCoordinator? notificationPrompt;

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
            ),
          ),
          EventDetailUnavailable(:final message) => _DetailScaffold(
            body: _MessageState(
              message: message,
              actionLabel: 'Retry',
              onActionPressed: _controller.retry,
            ),
          ),
          EventDetailError(:final message) => _DetailScaffold(
            body: _MessageState(
              message: message,
              actionLabel: 'Retry',
              onActionPressed: _controller.retry,
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
        toolbarHeight: 48,
        leadingWidth: 56,
        titleSpacing: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              )
            : const SizedBox.shrink(),
        title: Text(
          'On This Day',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepInk,
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['Times New Roman', 'serif'],
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
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
  });

  final HistoricalEvent event;
  final ValueChanged<EventSource> onSourceSelected;
  final SourceLauncher sourceLauncher;
  final OptionalImageLoader? imageLoader;
  final NotificationPromptCoordinator? notificationPrompt;

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
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 48),
      children: [
        _ArticleSurface(
          event: widget.event,
          imageLoader: widget.imageLoader,
          sourceLauncher: widget.sourceLauncher,
        ),
        const SizedBox(height: 42),
        Row(
          children: [
            const Icon(Icons.book_outlined, size: 18, color: AppColors.deepInk),
            const SizedBox(width: 8),
            Text(
              'READ MORE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.deepInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final source in widget.event.sources)
          SourceRow(
            source: source,
            onTap: () => widget.onSourceSelected(source),
          ),
        if (_reachedArticleEnd && notificationPrompt != null)
          NotificationPrePrompt(coordinator: notificationPrompt),
      ],
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

  @override
  Widget build(BuildContext context) {
    final image = event.primaryImage;
    final loader = imageLoader;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softIvory,
        border: Border.all(color: AppColors.paleStone),
      ),
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.historicalDate.toUpperCase(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.archivalCobalt,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.mutedCopper),
          const SizedBox(height: 18),
          Text(
            event.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.deepInk,
              fontFamily: 'Georgia',
              fontFamilyFallback: const ['Times New Roman', 'serif'],
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (image != null && loader != null) ...[
            OptionalEventImage(
              url: image.url,
              altText: image.altText,
              loader: loader,
              padding: const EdgeInsets.only(top: 28),
              caption: EventImageCredit(image: image, launcher: sourceLauncher),
            ),
          ],
          SizedBox(
            height:
                image != null &&
                    loader != null &&
                    EventImageCredit.summaryFor(image) != null
                ? 12
                : 28,
          ),
          Text(
            event.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.deepInk,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Loading event...'));
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.actionLabel,
    required this.onActionPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedGray),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onActionPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
