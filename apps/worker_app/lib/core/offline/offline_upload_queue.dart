import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kQueueKey = 'offline_photo_upload_queue';

/// A single item waiting in the offline upload queue.
class OfflineQueueItem {
  const OfflineQueueItem({
    required this.draftId,
    required this.bookingId,
    required this.filePath,
    required this.photoType, // 'before' or 'after'
    required this.enqueuedAt,
  });

  final String draftId;
  final String bookingId;
  final String filePath;
  final String photoType;
  final DateTime enqueuedAt;

  Map<String, dynamic> toJson() => {
        'draftId': draftId,
        'bookingId': bookingId,
        'filePath': filePath,
        'photoType': photoType,
        'enqueuedAt': enqueuedAt.toIso8601String(),
      };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) =>
      OfflineQueueItem(
        draftId: json['draftId'] as String,
        bookingId: json['bookingId'] as String,
        filePath: json['filePath'] as String,
        photoType: json['photoType'] as String,
        enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      );
}

/// Persists a queue of pending photo uploads across app restarts using
/// [SharedPreferences]. All operations are safe to call concurrently.
class OfflineUploadQueueService {
  OfflineUploadQueueService._();
  static final OfflineUploadQueueService instance = OfflineUploadQueueService._();

  Future<List<OfflineQueueItem>> pendingItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kQueueKey) ?? [];
    return raw
        .map((s) {
          try {
            return OfflineQueueItem.fromJson(
              json.decode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<OfflineQueueItem>()
        .toList();
  }

  Future<void> enqueue(OfflineQueueItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = List<String>.from(prefs.getStringList(_kQueueKey) ?? []);
    // Avoid duplicates
    raw.removeWhere((s) {
      try {
        final decoded = json.decode(s) as Map<String, dynamic>;
        return decoded['draftId'] == item.draftId;
      } catch (_) {
        return false;
      }
    });
    raw.add(json.encode(item.toJson()));
    await prefs.setStringList(_kQueueKey, raw);
  }

  Future<void> dequeue(String draftId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = List<String>.from(prefs.getStringList(_kQueueKey) ?? []);
    raw.removeWhere((s) {
      try {
        final decoded = json.decode(s) as Map<String, dynamic>;
        return decoded['draftId'] == draftId;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_kQueueKey, raw);
  }

  Future<void> clearForBooking(String bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = List<String>.from(prefs.getStringList(_kQueueKey) ?? []);
    raw.removeWhere((s) {
      try {
        final decoded = json.decode(s) as Map<String, dynamic>;
        return decoded['bookingId'] == bookingId;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_kQueueKey, raw);
  }
}
