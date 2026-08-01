import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'router.dart';
import '../core/realtime/realtime_socket_service.dart';
import '../features/onboarding/presentation/providers/onboarding_provider.dart';

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  WebSocketChannel? _notificationChannel;
  StreamSubscription? _notificationSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _activeUserId;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _disposeNotificationSocket();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(_registerDeviceToken());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(workerOnboardingStatusProvider);
    }
  }

  void _disposeNotificationSocket() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _notificationChannel?.sink.close();
    _notificationChannel = null;
    _activeUserId = null;
  }

  void _syncNotificationSocket(AsyncValue<AuthSession?>? _, AsyncValue<AuthSession?> next) {
    ref.invalidate(workerOnboardingStatusProvider);
    final session = next.valueOrNull;
    final nextUserId = session?.user.id;

    if (nextUserId == _activeUserId) {
      return;
    }

    _disposeNotificationSocket();

    if (session == null) {
      return;
    }

    final environment = ref.read(environmentProvider);
    _notificationChannel = connectNotificationSocket(
      apiBaseUrl: environment.apiBaseUrl,
      token: session.accessToken,
    );
    _activeUserId = nextUserId;

    _notificationSubscription = _notificationChannel!.stream.listen(
      (message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          final type = decoded['type'] as String?;
          final payload = decoded['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
          if (type == 'notification.event') {
            final title = payload['title'] as String? ?? 'Update';
            final body = payload['body'] as String? ?? 'You have a new notification.';
            final notificationType = payload['type'] as String? ?? '';
            if (notificationType.startsWith('WORKER_ONBOARDING_')) {
              ref.invalidate(workerOnboardingStatusProvider);
            }
            _messengerKey.currentState?.showSnackBar(
              SnackBar(content: Text('$title: $body')),
            );
          }
        } catch (_) {
          // Ignore malformed push messages.
        }
      },
      onError: (_) {
        _disposeNotificationSocket();
      },
    );

    unawaited(_registerDeviceToken());
  }

  Future<void> _registerDeviceToken() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    try {
      await ref.read(apiClientProvider).post(
            '/device-tokens',
            data: {
              'token': token,
              'platform': platform,
            },
          );
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, _syncNotificationSocket);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: appTitleForMode(AppMode.worker),
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => AppBackdrop(
        variant: AppBackdropVariant.worker,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: router,
    );
  }
}
