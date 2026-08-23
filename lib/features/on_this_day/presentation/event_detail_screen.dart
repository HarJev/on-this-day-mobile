import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/navigation/source_launcher.dart';
import '../domain/event_source.dart';
import '../domain/historical_event.dart';
import '../domain/on_this_day_repository.dart';
import 'event_detail_controller.dart';
import 'widgets/source_row.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.repository,
    required this.eventId,
    required this.sourceLauncher,
  }) : assert(eventId != '');

  final OnThisDayRepository repository;
  final String eventId;
  final SourceLauncher sourceLauncher;

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
            body: _LoadedState(event: event, onSourceSelected: _openSource),
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
      appBar: AppBar(title: const Text('On This Day')),
      body: SafeArea(child: body),
    );
  }
}

class _LoadedState extends StatelessWidget {
  const _LoadedState({required this.event, required this.onSourceSelected});

  final HistoricalEvent event;
  final ValueChanged<EventSource> onSourceSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(30, 72, 30, 56),
      children: [
        _ArticleSurface(event: event),
        const SizedBox(height: 72),
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
        const SizedBox(height: 22),
        for (final source in event.sources)
          SourceRow(source: source, onTap: () => onSourceSelected(source)),
      ],
    );
  }
}

class _ArticleSurface extends StatelessWidget {
  const _ArticleSurface({required this.event});

  final HistoricalEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softIvory,
        border: Border.all(color: AppColors.paleStone),
      ),
      padding: const EdgeInsets.fromLTRB(38, 42, 38, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.historicalDate.toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.archivalCobalt,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.mutedCopper),
          const SizedBox(height: 24),
          Text(
            event.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.deepInk,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          if (event.primaryImage case final image?) ...[
            const SizedBox(height: 42),
            AspectRatio(
              aspectRatio: 1.75,
              child: Image.network(
                image.url.toString(),
                fit: BoxFit.cover,
                semanticLabel: image.altText,
              ),
            ),
          ],
          const SizedBox(height: 42),
          Text(
            event.description,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.deepInk,
              fontWeight: FontWeight.w400,
              height: 1.55,
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
