import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

Future<void> registerWorkerDeviceToken(
  ApiClient api, {
  required String platform,
}) async {
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

Future<void> unregisterWorkerDeviceToken(ApiClient api) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await api
        .delete('/device-tokens', data: {'token': token})
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // Signing out must remain available if push-token cleanup cannot reach the API.
  }
}
