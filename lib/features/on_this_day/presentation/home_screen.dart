import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/timezone_provider.dart';
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
    required this.timezoneProvider,
    this.onShowDebugNotification,
  });

  final OnThisDayRepository repository;
  final TimezoneProvider timezoneProvider;
  final VoidCallback? onShowDebugNotification;

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
      timezoneProvider: widget.timezoneProvider,
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
          HomeLoading() => _HomeScaffold(
            onShowDebugNotification: widget.onShowDebugNotification,
            body: const _LoadingState(),
          ),
          HomeLoaded(:final content) => _HomeScaffold(
            displayDate: content.displayDate,
            onShowDebugNotification: widget.onShowDebugNotification,
            body: _LoadedState(content: content, onEventSelected: _openEvent),
          ),
          HomeUnavailable(:final message) => _HomeScaffold(
            onShowDebugNotification: widget.onShowDebugNotification,
            body: _MessageState(
              message: message,
              actionLabel: 'Retry',
              onActionPressed: _controller.retry,
            ),
          ),
          HomeError(:final message) => _HomeScaffold(
            onShowDebugNotification: widget.onShowDebugNotification,
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
  const _HomeScaffold({
    required this.body,
    this.displayDate,
    this.onShowDebugNotification,
  });

  final Widget body;
  final String? displayDate;
  final VoidCallback? onShowDebugNotification;

  @override
  Widget build(BuildContext context) {
    final appBarSideWidth = onShowDebugNotification == null ? 88.0 : 144.0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 48,
        leading: const SizedBox.shrink(),
        leadingWidth: appBarSideWidth,
        titleSpacing: 0,
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(
            color: AppColors.paleStone,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ),
        actions: [
          SizedBox(
            width: appBarSideWidth,
            child: Stack(
              children: [
                if (onShowDebugNotification case final callback?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Show test notification',
                      onPressed: callback,
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 22),
                    child: switch (displayDate) {
                      final date? => FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          date,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.deepInk,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                        ),
                      ),
                      null => const SizedBox.shrink(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(top: false, child: body),
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
      padding: const EdgeInsets.fromLTRB(30, 16, 30, 44),
      children: [
        FeaturedEventCard(
          event: content.featuredEvent,
          onTap: () => onEventSelected(content.featuredEvent.id),
        ),
        if (additionalEvents.isNotEmpty) ...[
          const SizedBox(height: 34),
          Text(
            'Also on this day',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.deepInk,
              fontFamily: 'Georgia',
              fontFamilyFallback: const ['Times New Roman', 'serif'],
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          const SizedBox(
            width: 198,
            child: Divider(color: AppColors.mutedCopper),
          ),
          const SizedBox(height: 14),
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
