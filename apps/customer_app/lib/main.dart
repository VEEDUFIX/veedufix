import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app/app.dart';

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
  unawaited(_initializePushNotifications(environment));
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
      options.environment = const String.fromEnvironment('APP_ENV', defaultValue: 'production');
      options.release = const String.fromEnvironment('APP_RELEASE', defaultValue: '');
    });
  } catch (_) {
    // Observability is optional and must never prevent app startup.
  }
}

Future<void> _initializePushNotifications(
  AppEnvironment environment,
) async {
  if (!environment.hasFirebaseConfig) {
    return;
  }

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await initializeFirebaseIfConfigured(environment);
    await FirebaseMessagingService.create().initialize();

  } catch (_) {
    // Push is an enhancement; keep the core booking app usable without it.
  }
}
