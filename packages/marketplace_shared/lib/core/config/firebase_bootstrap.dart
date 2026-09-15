import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'environment.dart';

Future<FirebaseApp?> initializeFirebaseIfConfigured(
  AppEnvironment environment,
) async {
  final options = environment.toFirebaseOptions();
  if (Firebase.apps.isNotEmpty) {
    return Firebase.app();
  }

  if (options != null) {
    return Firebase.initializeApp(options: options);
  }

  // Android and iOS load their Firebase configuration from the platform
  // files (google-services.json / GoogleService-Info.plist).
  if (!kIsWeb) {
    return Firebase.initializeApp();
  }

  return null;
}
