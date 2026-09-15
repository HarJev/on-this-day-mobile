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
import 'core/navigation/quiz_route_dependencies.dart';
import 'core/navigation/source_launcher.dart';
import 'core/notifications/device_platform_provider.dart';
import 'core/notifications/device_registration_client.dart';
import 'core/notifications/device_registration_coordinator.dart';
import 'core/notifications/local_notification_gateway.dart';
import 'core/notifications/notification_navigation_coordinator.dart';
import 'core/notifications/notification_service.dart';
import 'features/on_this_day/data/backend_on_this_day_repository.dart';
import 'features/quiz/application/quiz_completion_coordinator.dart';
import 'features/quiz/application/quiz_completion_id_generator.dart';
import 'features/quiz/application/quiz_root_status.dart';
import 'features/quiz/data/backend_quiz_repository.dart';
import 'features/quiz/data/local/quiz_database.dart';
import 'features/quiz/data/local/sqlite_quiz_result_store.dart';
import 'features/quiz/presentation/images/quiz_image_decoder.dart';
import 'features/quiz/presentation/images/quiz_image_downloader.dart';
import 'features/quiz/presentation/images/quiz_image_preparer.dart';
import 'firebase_options.dart';

const _debugNotificationEventId = String.fromEnvironment(
  'ON_THIS_DAY_DEBUG_NOTIFICATION_EVENT_ID',
  defaultValue: 'battle-of-bosworth-field-1485',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final config = AppConfig.fromEnvironment();
  final httpClient = http.Client();
  final apiClient = ApiClient(
    baseUrl: config.apiBaseUrl,
    httpClient: httpClient,
  );
  final repository = BackendOnThisDayRepository(apiClient: apiClient);
  const timezoneProvider = PlatformTimezoneProvider();
  final navigatorKey = GlobalKey<NavigatorState>();
  final routeObserver = RouteObserver<PageRoute<dynamic>>();
  final quizDatabase = QuizDatabase();
  final quizResultStore = SqliteQuizResultStore(database: quizDatabase);
  late final quizDependencies = QuizRouteDependencies(
    repository: BackendQuizRepository(apiClient: apiClient),
    resultStore: quizResultStore,
    completionCoordinator: QuizCompletionCoordinator(quizResultStore),
    imagePreparer: QuizImagePreparer(
      downloader: HttpQuizImageDownloader(httpClient),
      decoder: FlutterQuizImageDecoder(),
    ),
    timezoneProvider: timezoneProvider,
    completionIdGenerator: SecureQuizCompletionIdGenerator(),
    sourceLauncher: const PlatformSourceLauncher(),
    rootStatus: QuizRootStatus(),
  );
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
  runApp(
    OnThisDayApp(
      initialEventId: notificationStartup.initialEventId,
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
        navigatorKey: navigatorKey,
        routeObserver: routeObserver,
        quizDependencies: () => quizDependencies,
      ),
      routeObserver: routeObserver,
    ),
  );
}

class OnThisDayApp extends StatelessWidget {
  const OnThisDayApp({
    super.key,
    required AppRouter router,
    this.initialRoute = AppRoutes.root,
    this.initialEventId,
    this.navigatorKey,
    this.routeObserver,
  }) : _router = router;

  final AppRouter _router;
  final String initialRoute;
  final String? initialEventId;
  final GlobalKey<NavigatorState>? navigatorKey;
  final RouteObserver<PageRoute<dynamic>>? routeObserver;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On This Day',
      theme: AppTheme.light,
      navigatorKey: navigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: _router.onGenerateRoute,
      navigatorObservers: [routeObserver ?? _router.routeObserver],
      onGenerateInitialRoutes: (route) {
        final eventId = initialEventId;
        if (eventId == null) {
          return [_router.onGenerateRoute(RouteSettings(name: route))];
        }
        final root = _router.onGenerateRoute(
          const RouteSettings(name: AppRoutes.root),
        );
        return [
          root,
          _router.onGenerateRoute(
            RouteSettings(name: AppRoutes.eventDetail(eventId)),
          ),
        ];
      },
    );
  }
}
