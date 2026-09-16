import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true, the user has explicitly chosen to skip authentication.
/// The router allows unauthenticated users through to the app shell.
final guestModeProvider = StateProvider<bool>((ref) => false);
