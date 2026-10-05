import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'router.dart';
import '../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../features/worker/presentation/providers/earnings_provider.dart';
import '../features/worker/presentation/providers/worker_wallet_providers.dart';
import '../core/notifications/worker_device_token.dart';
import 'worker_notification_routes.dart';

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  late final bool _isFirebaseConfigured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFirebaseConfigured = ref.read(environmentProvider).hasFirebaseConfig;
    if (!_isFirebaseConfigured) {
      return;
    }
    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(_registerDeviceToken());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _notificationSubscription?.cancel();
    ref.read(realtimeServiceProvider).disconnectNotifications();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(workerOnboardingStatusProvider);
      if (ref.read(authControllerProvider).valueOrNull != null) {
        for (final tab in const [
          'incoming',
          'accepted',
          'active',
          'completed',
        ]) {
          ref.invalidate(workerJobsProvider(tab));
        }
        ref.invalidate(workerDashboardStatsProvider);
        ref.invalidate(workerWalletProvider);
        ref.invalidate(workerEarningsPageProvider);
        unawaited(_registerDeviceToken());
      }
    }
  }

  /// Called by [ref.listen] whenever auth state changes.
  /// Reconnects the notification socket for the new session, or disconnects
  /// when the user signs out.
  Future<void> _syncNotificationSocket(
    AsyncValue<AuthSession?>? _,
    AsyncValue<AuthSession?> next,
  ) async {
    ref.invalidate(workerOnboardingStatusProvider);

    final session = next.valueOrNull;
    if (session == null) {
      _notificationSubscription?.cancel();
      await ref.read(realtimeServiceProvider).disconnectNotifications();
      return;
    }

    // Reconnect — shared RealtimeService handles de-dup internally.
    final service = ref.read(realtimeServiceProvider);
    await service.connectNotifications();

    _notificationSubscription?.cancel();
    _notificationSubscription = service.notificationStream.listen((payload) {
      final title = payload['title'] as String? ?? 'Update';
      final body =
          payload['body'] as String? ?? 'You have a new notification.';
      final notificationType = payload['type'] is String
          ? payload['type'] as String
          : '';
      if (notificationType.startsWith('WORKER_ONBOARDING_')) {
        ref.invalidate(workerOnboardingStatusProvider);
      }
      final route = workerNotificationRoute(payload);
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('$title: $body'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => ref.read(routerProvider).push(route),
          ),
        ),
      );
    });

    unawaited(_registerDeviceToken());
  }

  Future<void> _registerDeviceToken() async {
    if (!_isFirebaseConfigured) {
      return;
    }
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    await registerWorkerDeviceToken(ref.read(apiClientProvider), platform: platform);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(
      authControllerProvider,
      (prev, next) => _syncNotificationSocket(prev, next),
    );
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: appTitleForMode(AppMode.worker),
      theme: buildLightTheme(),
      themeMode: ThemeMode.light,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ta')],
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => AppBackdrop(
        variant: AppBackdropVariant.worker,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NetworkStatusBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
      routerConfig: router,
    );
  }
}
