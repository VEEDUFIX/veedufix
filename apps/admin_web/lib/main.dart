import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'app/app.dart';
import 'app/router.dart';

void _handleAdminNotificationTap(RemoteMessage message, GoRouter router) {
  final data = message.data;
  final type = data['type'] as String?;

  switch (type) {
    case 'DISPUTE':
      router.push('/ops/disputes');
      break;
    case 'ALERT':
      router.push('/ops/alerts');
      break;
    case 'WORKER_ONBOARDING':
      router.push('/worker-review');
      break;
    case 'NEW_BOOKING':
      router.push('/admin-bookings');
      break;
    default:
      final route = data['route'] as String?;
      router.push(route ?? '/admin');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Defer optional messaging setup so an absent web Firebase configuration
  // never prevents the admin dashboard from starting.
  Future.microtask(() async {
    try {
      final environment = AppEnvironment.fromDartDefines();
      if (!environment.hasFirebaseConfig) {
        return;
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await initializeFirebaseIfConfigured(environment);
      await FirebaseMessagingService.create().initialize();

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleAdminNotificationTap(message, container.read(routerProvider));
      });

      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) {
        _handleAdminNotificationTap(message, container.read(routerProvider));
      }
    } catch (_) {
      // Notifications are non-critical for first render.
    }
  });

  runApp(UncontrolledProviderScope(
    container: container,
    child: const AppBootstrap(),
  ));
}
