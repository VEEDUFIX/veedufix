class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    required this.firebaseProjectId,
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
    const isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
    const googleServerClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    );

    return const AppEnvironment(
      apiBaseUrl: apiBaseUrl,
      firebaseProjectId: firebaseProjectId,
      isProduction: isProduction,
      googleServerClientId: googleServerClientId,
    );
  }

  final String apiBaseUrl;
  final String firebaseProjectId;
  final bool isProduction;
  final String googleServerClientId;
}
