import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../domain/daily_content.dart';
import '../domain/on_this_day_repository.dart';
import 'home_controller.dart';
import 'widgets/additional_event_row.dart';
import 'widgets/featured_event_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.timezone,
  }) : assert(timezone != '');

  final OnThisDayRepository repository;
  final String timezone;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(
      repository: widget.repository,
      timezone: widget.timezone,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.loadToday();
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
          HomeLoading() => const _HomeScaffold(body: _LoadingState()),
          HomeLoaded(:final content) => _HomeScaffold(
            displayDate: content.displayDate,
            body: _LoadedState(content: content, onEventSelected: _openEvent),
          ),
          HomeUnavailable(:final message) => _HomeScaffold(
            body: _MessageState(
              message: message,
              actionLabel: 'Retry',
              onActionPressed: _controller.retry,
            ),
          ),
          HomeError(:final message) => _HomeScaffold(
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

  void _openEvent(String eventId) {
    Navigator.of(context).pushNamed(AppRoutes.eventDetail(eventId));
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({required this.body, this.displayDate});

  final Widget body;
  final String? displayDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('On This Day'),
        actions: [
          if (displayDate case final date?)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Text(
                  date,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.deepInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _LoadedState extends StatelessWidget {
  const _LoadedState({required this.content, required this.onEventSelected});

  final DailyContent content;
  final ValueChanged<String> onEventSelected;

  @override
  Widget build(BuildContext context) {
    final additionalEvents = content.additionalEvents;

    return ListView(
      padding: const EdgeInsets.fromLTRB(30, 80, 30, 48),
      children: [
        FeaturedEventCard(
          event: content.featuredEvent,
          onTap: () => onEventSelected(content.featuredEvent.id),
        ),
        if (additionalEvents.isNotEmpty) ...[
          const SizedBox(height: 92),
          Text(
            'Also on this day',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.deepInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(
            width: 198,
            child: Divider(color: AppColors.mutedCopper),
          ),
          const SizedBox(height: 18),
          for (final event in additionalEvents)
            AdditionalEventRow(
              event: event,
              onTap: () => onEventSelected(event.id),
            ),
        ],
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Loading today's history..."));
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
