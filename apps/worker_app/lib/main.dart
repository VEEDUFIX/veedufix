import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app/app.dart';
import 'app/router.dart';

void _handleWorkerNotificationTap(RemoteMessage message, GoRouter router) {
  final data = message.data;
  final type = data['type'] as String?;
  final bookingId = data['bookingId'] as String?;

  switch (type) {
    case 'NEW_JOB':
    case 'JOB_ASSIGNED':
      router.push('/jobs');
      break;
    case 'CHAT':
      if (bookingId != null) router.push('/chat?bookingId=$bookingId');
      break;
    case 'PAYOUT':
    case 'EARNINGS':
      router.push('/wallet');
      break;
    case 'REVIEW':
      router.push('/reviews');
      break;
    default:
      final route = data['route'] as String?;
      router.push(route ?? '/notifications');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Defer Firebase and Messaging init so they do not block the first frame
  Future.microtask(() async {

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await initializeFirebaseIfConfigured(AppEnvironment.fromDartDefines());
  await FirebaseMessagingService.create().initialize();


  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleWorkerNotificationTap(message, container.read(routerProvider));
  });

  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      _handleWorkerNotificationTap(message, container.read(routerProvider));
    }
  });

    });

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(UncontrolledProviderScope(
      container: container,
      child: const AppBootstrap(),
    )),
  );
}
