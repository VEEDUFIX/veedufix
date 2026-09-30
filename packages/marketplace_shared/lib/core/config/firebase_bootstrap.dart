import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'environment.dart';

Future<FirebaseApp?>? _firebaseInitialization;

Future<FirebaseApp?> initializeFirebaseIfConfigured(AppEnvironment environment) {
  if (Firebase.apps.isNotEmpty) {
    return Future.value(Firebase.app());
  }

  final pendingInitialization = _firebaseInitialization;
  if (pendingInitialization != null) {
    return pendingInitialization;
  }

  final initialization = _initializeFirebase(environment);
  _firebaseInitialization = initialization;
  return initialization.catchError((Object error, StackTrace stackTrace) {
    if (identical(_firebaseInitialization, initialization)) {
      _firebaseInitialization = null;
    }
    Error.throwWithStackTrace(error, stackTrace);
  });
}

Future<FirebaseApp?> _initializeFirebase(AppEnvironment environment) async {
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
