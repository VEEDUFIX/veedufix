import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'router.dart';
import '../features/onboarding/presentation/providers/onboarding_provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      final notificationType = payload['type'] as String? ?? '';
      if (notificationType.startsWith('WORKER_ONBOARDING_')) {
        ref.invalidate(workerOnboardingStatusProvider);
      }
      _messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('$title: $body')));
    });

    unawaited(_registerDeviceToken());
  }

  Future<void> _registerDeviceToken() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    try {
      await ref.read(apiClientProvider).post(
        '/device-tokens',
        data: {'token': token, 'platform': platform},
      );
    } catch (_) {
      // Best-effort only — never block the app for a token registration failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(
      authControllerProvider,
      (prev, next) => _syncNotificationSocket(prev, next),
    );
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: appTitleForMode(AppMode.worker),
      theme: buildLightTheme(),
      themeMode: ThemeMode.light,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => AppBackdrop(
        variant: AppBackdropVariant.worker,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: router,
    );
  }
}
