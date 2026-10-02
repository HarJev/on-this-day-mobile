import 'package:flutter/material.dart';

import '../../../core/images/cached_optional_image_loader.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/app_theme.dart';
import '../../../core/config/timezone_provider.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/navigation/event_detail_route_arguments.dart';
import '../../../core/navigation/source_launcher.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../domain/daily_content.dart';
import '../domain/on_this_day_repository.dart';
import '../domain/recent_day.dart';
import 'home_controller.dart';
import 'widgets/additional_event_row.dart';
import 'widgets/featured_event_card.dart';
import 'widgets/recent_day_row.dart';
import 'widgets/today_states.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.timezoneProvider,
    this.onShowDebugNotification,
    this.embedded = false,
    this.onDisplayDateChanged,
    this.imageLoader,
    this.sourceLauncher = const PlatformSourceLauncher(),
    this.telemetry = const NoopAppTelemetry(),
  });

  final OnThisDayRepository repository;
  final TimezoneProvider timezoneProvider;
  final VoidCallback? onShowDebugNotification;
  final bool embedded;
  final ValueChanged<String?>? onDisplayDateChanged;
  final OptionalImageLoader? imageLoader;
  final SourceLauncher sourceLauncher;
  final AppTelemetry telemetry;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  String? _reportedDisplayDate;

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
        final displayDate = switch (state) {
          HomeLoaded(:final content) => content.displayDate,
          _ => null,
        };
        _reportDisplayDate(displayDate);

        return switch (state) {
          HomeLoading() => _HomeScaffold(
            embedded: widget.embedded,
            onShowDebugNotification: widget.onShowDebugNotification,
            body: const TodayLoadingSkeleton(),
          ),
          HomeLoaded(:final content, :final recentDays) => _HomeScaffold(
            embedded: widget.embedded,
            displayDate: content.displayDate,
            onShowDebugNotification: widget.onShowDebugNotification,
            body: _LoadedState(
              content: content,
              recentDays: recentDays,
              onEventSelected: _openTodayEvent,
              onRecentEventSelected: _openEvent,
              imageLoader: widget.imageLoader,
              sourceLauncher: widget.sourceLauncher,
            ),
          ),
          HomeUnavailable(:final message) => _HomeScaffold(
            embedded: widget.embedded,
            onShowDebugNotification: widget.onShowDebugNotification,
            body: TodayMessageCard(
              icon: Icons.event_busy_outlined,
              title: message,
              message: 'Please try again in a little while.',
              actionLabel: 'Try again',
              onActionPressed: _controller.retry,
            ),
          ),
          HomeError(:final message) => _HomeScaffold(
            embedded: widget.embedded,
            onShowDebugNotification: widget.onShowDebugNotification,
            body: TodayMessageCard(
              icon: Icons.cloud_off_outlined,
              title: message,
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onActionPressed: _controller.retry,
            ),
          ),
        };
      },
    );
  }

  void _reportDisplayDate(String? displayDate) {
    if (_reportedDisplayDate == displayDate) return;
    _reportedDisplayDate = displayDate;
    if (displayDate != null) widget.telemetry.todayLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDisplayDateChanged?.call(displayDate);
    });
  }

  void _openTodayEvent(String eventId) {
    Navigator.of(context).pushNamed(
      AppRoutes.eventDetail(eventId),
      arguments: const EventDetailRouteArguments(isToday: true),
    );
  }

  void _openEvent(String eventId) {
    widget.telemetry.recentOpened();
    Navigator.of(context).pushNamed(AppRoutes.eventDetail(eventId));
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({
    required this.body,
    required this.embedded,
    this.displayDate,
    this.onShowDebugNotification,
  });

  final Widget body;
  final bool embedded;
  final String? displayDate;
  final VoidCallback? onShowDebugNotification;

  @override
  Widget build(BuildContext context) {
    if (embedded) return body;
    final appBarSideWidth = onShowDebugNotification == null ? 72.0 : 120.0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 56,
        leading: const SizedBox.shrink(),
        leadingWidth: appBarSideWidth,
        titleSpacing: 0,
        title: const Text('On This Day', style: AppText.masthead),
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
            child: Row(
              children: [
                if (onShowDebugNotification case final callback?)
                  IconButton(
                    tooltip: 'Show test notification',
                    onPressed: callback,
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: switch (displayDate) {
                      final date? => Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            date,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(fontSize: 14),
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
  const _LoadedState({
    required this.content,
    required this.recentDays,
    required this.onEventSelected,
    required this.onRecentEventSelected,
    required this.sourceLauncher,
    this.imageLoader,
  });

  final DailyContent content;
  final List<RecentDay> recentDays;
  final ValueChanged<String> onEventSelected;
  final ValueChanged<String> onRecentEventSelected;
  final SourceLauncher sourceLauncher;
  final OptionalImageLoader? imageLoader;

  @override
  Widget build(BuildContext context) {
    final additionalEvents = content.additionalEvents;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Featured',
            style: AppText.eyebrow.copyWith(color: AppColors.archivalCobalt),
          ),
        ),
        FeaturedEventCard(
          event: content.featuredEvent,
          onTap: () => onEventSelected(content.featuredEvent.id),
          imageLoader: imageLoader,
          sourceLauncher: sourceLauncher,
        ),
        if (additionalEvents.isNotEmpty) ...[
          const SizedBox(height: 32),
          const TodaySectionHeader('Also on this day'),
          for (final event in additionalEvents)
            AdditionalEventRow(
              event: event,
              onTap: () => onEventSelected(event.id),
            ),
        ],
        if (recentDays.isNotEmpty) ...[
          const SizedBox(height: 32),
          const TodaySectionHeader('Recent days'),
          for (final day in recentDays)
            RecentDayRow(
              day: day,
              onTap: () => onRecentEventSelected(day.featuredEvent.id),
            ),
        ],
      ],
    );
  }
}
