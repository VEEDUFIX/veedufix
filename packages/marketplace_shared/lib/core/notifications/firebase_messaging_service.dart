import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class FirebaseMessagingService {
  FirebaseMessagingService(this._messaging);

  factory FirebaseMessagingService.create() =>
      FirebaseMessagingService(FirebaseMessaging.instance);

  final FirebaseMessaging _messaging;
  static final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Map<String, dynamic>? _pendingTapPayload;

  static Stream<Map<String, dynamic>> get notificationTapStream =>
      _notificationTapController.stream;

  static Map<String, dynamic>? consumePendingTapPayload() {
    final payload = _pendingTapPayload;
    _pendingTapPayload = null;
    return payload;
  }

  Future<void> initialize() async {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('FCM permission status: ${settings.authorizationStatus}');
    }

    final token = await _messaging.getToken();
    if (kDebugMode && token != null) {
      debugPrint('FCM token: $token');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (kDebugMode) {
        debugPrint('FCM token refreshed: $token');
      }
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _pendingTapPayload = _normalizeTapPayload(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = _normalizeTapPayload(message);
      if (_notificationTapController.isClosed) {
        _pendingTapPayload = payload;
        return;
      }
      _notificationTapController.add(payload);
    });
  }

  static Map<String, dynamic> _normalizeTapPayload(RemoteMessage message) {
    final data = <String, dynamic>{};
    data.addAll(message.data);

    final nestedPayload = message.data['payload'];
    if (nestedPayload is String && nestedPayload.isNotEmpty) {
      data['payload'] = nestedPayload;
    }

    return data;
  }
}
