import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

const customerPushEnabledPreferenceKey = 'customer_push_notifications_enabled';

Future<bool> customerPushNotificationsEnabled() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(customerPushEnabledPreferenceKey) ?? true;
}

Future<bool> updateCustomerPushNotifications(
  ApiClient api, {
  required bool enabled,
}) async {
  final preferences = await SharedPreferences.getInstance();
  if (enabled) {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    await preferences.setBool(customerPushEnabledPreferenceKey, true);
    await registerCustomerDeviceToken(
      api,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
    );
    return true;
  }

  await preferences.setBool(customerPushEnabledPreferenceKey, false);
  await unregisterCustomerDeviceToken(api);
  try {
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {
    // The saved preference prevents this device from registering again.
  }
  return true;
}

Future<void> registerCustomerDeviceToken(
  ApiClient api, {
  required String platform,
}) async {
  try {
    if (!await customerPushNotificationsEnabled()) return;
  } catch (_) {
    return;
  }
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await api
          .post('/device-tokens', data: {'token': token, 'platform': platform})
          .timeout(const Duration(seconds: 8));
      return;
    } catch (_) {
      if (attempt == 2) return;
      await Future<void>.delayed(Duration(seconds: attempt + 1));
    }
  }
}

Future<void> unregisterCustomerDeviceToken(ApiClient api) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await api
        .delete('/device-tokens', data: {'token': token})
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // Logout must still work if push-token cleanup cannot reach the API.
  }
}
