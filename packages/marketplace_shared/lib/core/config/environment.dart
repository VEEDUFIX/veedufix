import 'package:firebase_core/firebase_core.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    required this.firebaseProjectId,
    required this.firebaseApiKey,
    required this.firebaseAppId,
    required this.firebaseMessagingSenderId,
    required this.firebaseStorageBucket,
    required this.firebaseAuthDomain,
    required this.firebaseDatabaseUrl,
    required this.firebaseMeasurementId,
    required this.razorpayKeyId,
    required this.isProduction,
    required this.googleServerClientId,
  });

  factory AppEnvironment.fromDartDefines() {
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:4000/api',
    );
    const firebaseProjectId = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: '',
    );
    const firebaseApiKey = String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: '',
    );
    const firebaseAppId = String.fromEnvironment(
      'FIREBASE_APP_ID',
      defaultValue: '',
    );
    const firebaseMessagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    );
    const firebaseStorageBucket = String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: '',
    );
    const firebaseAuthDomain = String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: '',
    );
    const firebaseDatabaseUrl = String.fromEnvironment(
      'FIREBASE_DATABASE_URL',
      defaultValue: '',
    );
    const firebaseMeasurementId = String.fromEnvironment(
      'FIREBASE_MEASUREMENT_ID',
      defaultValue: '',
    );
    const razorpayKeyId = String.fromEnvironment(
      'RAZORPAY_KEY_ID',
      defaultValue: '',
    );
    const isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
    const googleServerClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    );

    return const AppEnvironment(
      apiBaseUrl: apiBaseUrl,
      firebaseProjectId: firebaseProjectId,
      firebaseApiKey: firebaseApiKey,
      firebaseAppId: firebaseAppId,
      firebaseMessagingSenderId: firebaseMessagingSenderId,
      firebaseStorageBucket: firebaseStorageBucket,
      firebaseAuthDomain: firebaseAuthDomain,
      firebaseDatabaseUrl: firebaseDatabaseUrl,
      firebaseMeasurementId: firebaseMeasurementId,
      razorpayKeyId: razorpayKeyId,
      isProduction: isProduction,
      googleServerClientId: googleServerClientId,
    );
  }

  final String apiBaseUrl;
  final String firebaseProjectId;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;
  final String firebaseStorageBucket;
  final String firebaseAuthDomain;
  final String firebaseDatabaseUrl;
  final String firebaseMeasurementId;
  final String razorpayKeyId;
  final bool isProduction;
  final String googleServerClientId;

  bool get hasFirebaseConfig =>
      firebaseProjectId.isNotEmpty &&
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty;

  FirebaseOptions? toFirebaseOptions() {
    if (!hasFirebaseConfig) {
      return null;
    }

    return FirebaseOptions(
      apiKey: firebaseApiKey,
      appId: firebaseAppId,
      messagingSenderId: firebaseMessagingSenderId,
      projectId: firebaseProjectId,
      authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
      databaseURL: firebaseDatabaseUrl.isEmpty ? null : firebaseDatabaseUrl,
      storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
      measurementId:
          firebaseMeasurementId.isEmpty ? null : firebaseMeasurementId,
    );
  }
}
