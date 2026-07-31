import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─── Background handler (top-level) ──────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Messages received in background are shown by the OS automatically
  // We just ensure the app data is processed
}

// ─── Provider ────────────────────────────────────────────────────────────────

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService._();
});

// ─── Service ─────────────────────────────────────────────────────────────────

class FcmService {
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Callback when a notification is tapped (foreground or background)
  void Function(String? route, Map<String, dynamic> data)? onNotificationTap;

  Future<void> initialize({
    required void Function(String? route, Map<String, dynamic> data) onTap,
  }) async {
    onNotificationTap = onTap;

    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Init local notifications for foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        final payloadStr = details.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          try {
            final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
            final route = payload['route'] as String?;
            onNotificationTap?.call(route, payload);
          } catch (_) {}
        }
      },
    );

    // Create notification channel (Android)
    const channel = AndroidNotificationChannel(
      'veedufix_high',
      'VeeduFix Notifications',
      description: 'Booking updates and job notifications',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? 'VeeduFix',
          body: notification.body ?? '',
          data: message.data,
        );
      }
    });

    // App opened from notification (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = message.data['route'] as String?;
      onNotificationTap?.call(route, message.data);
    });

    // App launched from terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final route = initialMessage.data['route'] as String?;
      onNotificationTap?.call(route, initialMessage.data);
    }
  }

  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  Stream<String> get tokenRefreshStream => _messaging.onTokenRefresh;

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'veedufix_high',
      'VeeduFix Notifications',
      channelDescription: 'Booking updates and job notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }
}
