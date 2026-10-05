import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_mode.dart';

/// Stores unsent chat text locally, separated by app, account, and booking.
class ChatDraftStore {
  const ChatDraftStore._();

  static String _key({
    required AppMode mode,
    required String userId,
    required String bookingId,
  }) =>
      'veedufix.chat_draft.v1.${mode.name}.${Uri.encodeComponent(userId)}.${Uri.encodeComponent(bookingId)}';

  static Future<String?> read({
    required AppMode mode,
    required String userId,
    required String bookingId,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(
        _key(mode: mode, userId: userId, bookingId: bookingId),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> write({
    required AppMode mode,
    required String userId,
    required String bookingId,
    required String message,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _key(mode: mode, userId: userId, bookingId: bookingId);
      if (message.trim().isEmpty) {
        await preferences.remove(key);
      } else {
        await preferences.setString(key, message);
      }
    } catch (_) {
      // Draft persistence must never interrupt chat composition or sending.
    }
  }

  static Future<void> clear({
    required AppMode mode,
    required String userId,
    required String bookingId,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(
        _key(mode: mode, userId: userId, bookingId: bookingId),
      );
    } catch (_) {
      // The server message remains sent even if local cleanup fails.
    }
  }
}
