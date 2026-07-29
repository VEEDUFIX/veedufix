import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'app/app.dart';
import 'app/router.dart';

void _handleNotificationTap(RemoteMessage message, GoRouter router) {
  final data = message.data;
  final type = data['type'] as String?;
  final bookingId = data['bookingId'] as String?;

  switch (type) {
    case 'BOOKING':
    case 'JOB_UPDATE':
      if (bookingId != null) router.push('/tracking?bookingId=$bookingId');
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
      router.push('/notifications');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseIfConfigured(AppEnvironment.fromDartDefines());
  await FirebaseMessagingService.create().initialize();

  final container = ProviderContainer();

  // Handle notification tap when app is in background/terminated
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationTap(message, container.read(routerProvider));
  });

  // Handle notification tap when app was terminated
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _handleNotificationTap(message, container.read(routerProvider));
  });

  runApp(UncontrolledProviderScope(
    container: container,
    child: const AppBootstrap(),
  ));
}
