import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/realtime/realtime_socket_service.dart';
import '../features/auth/providers/guest_mode_provider.dart';
import '../core/notifications/customer_device_token.dart';
import 'router.dart';

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  WebSocketChannel? _notificationChannel;
  StreamSubscription? _notificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _firebaseAuthSubscription;
  StreamSubscription<void>? _sessionExpiredSubscription;
  bool _isRecoveringBackendSession = false;
  String? _activeUserId;
  Map<String, dynamic>? _pendingNotificationTap;
  late final bool _isFirebaseConfigured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFirebaseConfigured = ref.read(environmentProvider).hasFirebaseConfig;
    _sessionExpiredSubscription = ref.read(apiClientProvider).sessionExpired.listen((_) {
      unawaited(_handleExpiredBackendSession());
    });
    if (!_isFirebaseConfigured) {
      return;
    }
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
    _firebaseAuthSubscription = FirebaseAuth.instance.idTokenChanges().listen((_) {
      unawaited(_restoreBackendSessionFromFirebase());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTapSubscription?.cancel();
    _notificationTapSubscription = null;
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _firebaseAuthSubscription?.cancel();
    _firebaseAuthSubscription = null;
    _sessionExpiredSubscription?.cancel();
    _sessionExpiredSubscription = null;
    _disposeNotificationSocket();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authControllerProvider).valueOrNull != null) {
      unawaited(_registerDeviceToken());
    }
  }

  Future<bool> _restoreBackendSessionFromFirebase({bool force = false}) async {
    if (!_isFirebaseConfigured || _isRecoveringBackendSession) {
      return false;
    }
    if (ref.read(guestModeProvider) ||
        (!force && ref.read(authControllerProvider).valueOrNull != null)) {
      return ref.read(authControllerProvider).valueOrNull != null;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return false;
    }

    _isRecoveringBackendSession = true;
    try {
      final idToken = await firebaseUser.getIdToken(true);
      if (idToken != null) {
        await ref
            .read(authControllerProvider.notifier)
            .refreshFirebasePhoneSession(idToken: idToken);
        return ref.read(authControllerProvider).valueOrNull != null;
      }
    } catch (_) {
      // The login screen remains available if Firebase cannot restore the API session.
    } finally {
      _isRecoveringBackendSession = false;
    }
    return false;
  }

  Future<void> _handleExpiredBackendSession() async {
    if (_isRecoveringBackendSession || ref.read(guestModeProvider)) return;
    if (await _restoreBackendSessionFromFirebase(force: true)) return;
    if (!mounted) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // The backend session is still cleared below.
    }
    if (!mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
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
    if (!_isFirebaseConfigured) {
      return;
    }
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return;
    }

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    await registerCustomerDeviceToken(
      ref.read(apiClientProvider),
      platform: platform,
    );
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

    final safeBookingId = bookingId == null || bookingId.isEmpty
        ? null
        : Uri.encodeComponent(bookingId);

    switch (type?.toUpperCase()) {
      case 'BOOKING_CONFIRMED':
      case 'BOOKING_DETAIL':
        if (safeBookingId != null) return '/booking/$safeBookingId';
        break;
      case 'BOOKING':
      case 'JOB_UPDATE':
      case 'WORKER_ASSIGNED':
      case 'WORKER_EN_ROUTE':
      case 'WORKER_ARRIVED':
        if (safeBookingId != null) return '/tracking?bookingId=$safeBookingId';
        break;
      case 'BOOKING_COMPLETED':
        if (safeBookingId != null) return '/invoice/$safeBookingId';
        break;
      case 'REVIEW_REQUEST':
      case 'RATING_REQUESTED':
        if (safeBookingId != null) return '/booking-rating?bookingId=$safeBookingId';
        break;
      case 'ARRIVAL_STATUS_CHANGED':
        if (safeBookingId != null) return '/arrival-otp?bookingId=$safeBookingId';
        break;
      case 'COMPLETION_OTP_REQUESTED':
        if (safeBookingId != null) return '/completion-otp?bookingId=$safeBookingId';
        break;
      case 'PAYMENT':
      case 'WALLET':
        return '/wallet';
      case 'PROMO':
      case 'OFFER':
        return '/offers';
      case 'CHAT':
        if (safeBookingId != null) return '/chat?bookingId=$safeBookingId';
        break;
    }

    final requestedRoute = _firstString([
      payload['route'],
      data['route'],
      payloadData['route'],
    ]);
    final routeUri = requestedRoute == null ? null : Uri.tryParse(requestedRoute);
    final isAllowedRoute = routeUri != null &&
        !routeUri.hasScheme &&
        !routeUri.hasAuthority &&
        routeUri.path.startsWith('/') &&
        allowedRoutesForMode(AppMode.customer).any(
          (path) => routeUri.path == path || routeUri.path.startsWith('$path/'),
        );
    return isAllowedRoute ? routeUri.toString() : '/notifications';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, _syncNotificationSocket);
    // Handle pending notification taps when a session becomes available.
    // This must be a separate listener — not called in build() directly —
    // to avoid triggering navigation mid-rebuild.
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (_, next) {
      if (next.valueOrNull != null) {
        _tryHandlePendingNotificationTap();
      } else if (next.hasValue) {
        unawaited(_restoreBackendSessionFromFirebase());
      }
    });
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: appTitleForMode(AppMode.customer),
      theme: buildLightTheme(),
      themeMode: ThemeMode.light,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ta')],
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => AppBackdrop(
        variant: AppBackdropVariant.customer,
        child: child ?? const SplashPage(mode: AppMode.customer),
      ),
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
