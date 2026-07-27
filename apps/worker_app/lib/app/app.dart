import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  WebSocketChannel? _notificationChannel;
  StreamSubscription? _notificationSubscription;
  String? _activeUserId;

  @override
  void dispose() {
    _disposeNotificationSocket();
    super.dispose();
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
      routerConfig: router,
    );
  }
}
