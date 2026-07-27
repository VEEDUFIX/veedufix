import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseIfConfigured(AppEnvironment.fromDartDefines());
  await FirebaseMessagingService.create().initialize();
  runApp(const ProviderScope(child: AppBootstrap()));
}
