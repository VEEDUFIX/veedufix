import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/realtime/realtime_socket_service.dart';
import 'router.dart';

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  WebSocketChannel? _notificationChannel;
  StreamSubscription? _notificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _activeUserId;
  Map<String, dynamic>? _pendingNotificationTap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingNotificationTap = FirebaseMessagingService.consumePendingTapPayload();
      _tryHandlePendingNotificationTap();
    });
    _notificationTapSubscription = FirebaseMessagingService.notificationTapStream.listen((payload) {
      _pendingNotificationTap = payload;
      _tryHandlePendingNotificationTap();
    });
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(_registerDeviceToken());
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    _notificationTapSubscription = null;
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
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
            _routeNotificationPayload(payload);
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
      // Token registration is best-effort and should never block the app.
    }
  }

  void _routeNotificationPayload(Map<String, dynamic> payload) {
    final route = _notificationRouteForPayload(payload);
    if (route == null) {
      return;
    }
    ref.read(routerProvider).push(route);
  }

  void _tryHandlePendingNotificationTap() {
    final payload = _pendingNotificationTap;
    if (payload == null) {
      return;
    }

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return;
    }

    final route = _notificationRouteForPayload(payload);
    if (route == null) {
      return;
    }

    _pendingNotificationTap = null;
    if (!mounted) {
      return;
    }
    ref.read(routerProvider).push(route);
  }

  String? _notificationRouteForPayload(Map<String, dynamic> payload) {
    final type = _stringValue(payload['type']) ??
        _stringValue(payload['eventType']) ??
        _stringValue(_asMap(payload['payload'])['type']) ??
        _stringValue(_asMap(payload['payload'])['eventType']) ??
        _stringValue(payload['notificationType']);
    final data = _asMap(payload['data']);
    final payloadData = _asMap(payload['payload']);
    final bookingId = _firstString([
      payload['bookingId'],
      payload['booking_id'],
      data['bookingId'],
      data['booking_id'],
      payloadData['bookingId'],
      payloadData['booking_id'],
    ]);

    if (type == null || bookingId == null || bookingId.isEmpty) {
      return null;
    }

    return switch (type) {
      'arrival_status_changed' => '/arrival-otp?bookingId=$bookingId',
      'completion_otp_requested' => '/completion-otp?bookingId=$bookingId',
      'rating_requested' => '/booking-rating?bookingId=$bookingId',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, _syncNotificationSocket);
    _tryHandlePendingNotificationTap();
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: appTitleForMode(AppMode.customer),
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: router,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {
        // Ignore non-JSON strings.
      }
    }
    return <String, dynamic>{};
  }

  String? _firstString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = _stringValue(value);
      if (text != null) {
        return text;
      }
    }
    return null;
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
