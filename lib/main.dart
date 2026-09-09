import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/api/api_client.dart';
import 'core/config/app_config.dart';
import 'core/config/app_theme.dart';
import 'core/config/timezone_provider.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/app_routes.dart';
import 'core/notifications/device_platform_provider.dart';
import 'core/notifications/device_registration_client.dart';
import 'core/notifications/device_registration_coordinator.dart';
import 'core/notifications/local_notification_gateway.dart';
import 'core/notifications/notification_navigation_coordinator.dart';
import 'core/notifications/notification_service.dart';
import 'features/on_this_day/data/backend_on_this_day_repository.dart';
import 'firebase_options.dart';

const _debugNotificationEventId = String.fromEnvironment(
  'ON_THIS_DAY_DEBUG_NOTIFICATION_EVENT_ID',
  defaultValue: 'battle-of-bosworth-field-1485',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final config = AppConfig.fromEnvironment();
  final apiClient = ApiClient(
    baseUrl: config.apiBaseUrl,
    httpClient: http.Client(),
  );
  final repository = BackendOnThisDayRepository(apiClient: apiClient);
  const timezoneProvider = PlatformTimezoneProvider();
  final navigatorKey = GlobalKey<NavigatorState>();
  final notificationService = NotificationService(
    messaging: FirebaseNotificationMessaging(),
    localNotifications: PlatformLocalNotificationGateway(),
  );
  final notificationStartup = await notificationService.start();
  final deviceRegistrationCoordinator = DeviceRegistrationCoordinator(
    client: DeviceRegistrationClient(apiClient: apiClient),
    timezoneProvider: timezoneProvider,
    platformProvider: const PlatformDevicePlatformProvider(),
    notificationService: notificationService,
  );
  unawaited(deviceRegistrationCoordinator.start(notificationStartup));

  final notificationNavigationCoordinator = NotificationNavigationCoordinator(
    navigatorKey: navigatorKey,
  );
  unawaited(
    notificationNavigationCoordinator.start(
      notificationService.notificationTaps,
    ),
  );
  final initialRoute = switch (notificationStartup.initialEventId) {
    final eventId? => AppRoutes.eventDetail(eventId),
    null => AppRoutes.today,
  };

  runApp(
    OnThisDayApp(
      initialRoute: initialRoute,
      navigatorKey: navigatorKey,
      router: AppRouter(
        repository: repository,
        timezoneProvider: timezoneProvider,
        onShowDebugNotification: kDebugMode
            ? () => unawaited(
                notificationService.showDebugTestNotification(
                  eventId: _debugNotificationEventId,
                ),
              )
            : null,
      ),
    ),
  );
}

class OnThisDayApp extends StatelessWidget {
  const OnThisDayApp({
    super.key,
    required AppRouter router,
    this.initialRoute = AppRoutes.today,
    this.navigatorKey,
  }) : _router = router;

  final AppRouter _router;
  final String initialRoute;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On This Day',
      theme: AppTheme.light,
      navigatorKey: navigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}
