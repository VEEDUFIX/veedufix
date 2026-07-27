import 'package:firebase_core/firebase_core.dart';

import 'environment.dart';

Future<FirebaseApp?> initializeFirebaseIfConfigured(
  AppEnvironment environment,
) async {
  final options = environment.toFirebaseOptions();
  if (options == null) {
    return null;
  }

  if (Firebase.apps.isNotEmpty) {
    return Firebase.app();
  }

  return Firebase.initializeApp(options: options);
}
