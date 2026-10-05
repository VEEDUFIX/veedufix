import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'app/worker_notification_routes.dart';

void _handleWorkerNotificationTap(RemoteMessage message, GoRouter router) {
  router.push(workerNotificationRoute(message.data));
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  final environment = AppEnvironment.fromDartDefines();

  // Paint the Flutter shell immediately. Monitoring and push setup must never
  // hold the native launch screen open.
  runApp(UncontrolledProviderScope(
    container: container,
    child: const AppBootstrap(),
  ));

  unawaited(_initializeSentry());
  unawaited(_initializePushNotifications(container, environment));
}

Future<void> _initializeSentry() async {
  try {
    const dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    if (dsn.isEmpty) return;

    const configuredSampleRate = String.fromEnvironment(
      'SENTRY_TRACES_SAMPLE_RATE',
      defaultValue: '0.1',
    );
    final sampleRate = (double.tryParse(configuredSampleRate) ?? 0.1)
        .clamp(0.0, 1.0)
        .toDouble();
    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.tracesSampleRate = sampleRate;
      options.environment = const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'production',
      );
      options.release = const String.fromEnvironment('APP_RELEASE', defaultValue: '');
    });
  } catch (_) {
    // Observability is optional and must never prevent app startup.
  }
}

Future<void> _initializePushNotifications(
  ProviderContainer container,
  AppEnvironment environment,
) async {
  if (!environment.hasFirebaseConfig) {
    return;
  }

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await initializeFirebaseIfConfigured(environment);
    await FirebaseMessagingService.create().initialize();

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleWorkerNotificationTap(message, container.read(routerProvider));
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleWorkerNotificationTap(message, container.read(routerProvider));
      }
    });
  } catch (_) {
    // Push is an enhancement; keep the core worker app usable without it.
  }
}
