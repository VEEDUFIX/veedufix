import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app/app.dart';
import 'app/router.dart';

void _handleNotificationTap(RemoteMessage message, GoRouter router) {
  final data = message.data;
  final type = data['type'] as String?;
  final bookingId = data['bookingId'] as String?;

  switch (type) {
    case 'BOOKING_CONFIRMED':
    case 'BOOKING_DETAIL':
      if (bookingId != null) router.push('/booking/$bookingId');
      break;
    case 'BOOKING':
    case 'JOB_UPDATE':
    case 'WORKER_ASSIGNED':
    case 'WORKER_EN_ROUTE':
    case 'WORKER_ARRIVED':
      if (bookingId != null) router.push('/tracking?bookingId=$bookingId');
      break;
    case 'BOOKING_COMPLETED':
      if (bookingId != null) router.push('/invoice/$bookingId');
      break;
    case 'REVIEW_REQUEST':
      if (bookingId != null) router.push('/booking-rating?bookingId=$bookingId');
      break;
    case 'PAYMENT':
    case 'WALLET':
      router.push('/wallet');
      break;
    case 'PROMO':
    case 'OFFER':
      router.push('/offers');
      break;
    case 'CHAT':
      if (bookingId != null) router.push('/chat?bookingId=$bookingId');
      break;
    default:
      // Use generic route if provided in payload
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


  // Handle notification tap when app is in background/terminated
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationTap(message, container.read(routerProvider));
  });

  // Handle notification tap when app was terminated
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _handleNotificationTap(message, container.read(routerProvider));
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
