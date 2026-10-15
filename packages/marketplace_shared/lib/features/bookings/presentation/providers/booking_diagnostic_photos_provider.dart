import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class BookingDiagnosticPhoto {
  const BookingDiagnosticPhoto(
      {required this.id,
      required this.url,
      required this.bytes,
      required this.createdAt});
  final String id;
  final String url;
  final int bytes;
  final DateTime createdAt;

  factory BookingDiagnosticPhoto.fromJson(Map<String, dynamic> json) =>
      BookingDiagnosticPhoto(
        id: json['id'] as String,
        url: json['url'] as String,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

final bookingDiagnosticPhotosProvider = FutureProvider.autoDispose
    .family<List<BookingDiagnosticPhoto>, String>((ref, bookingId) async {
  final response = await ref
      .watch(apiClientProvider)
      .get('/bookings/$bookingId/diagnostic-photos');
  final rows = (response as Map<dynamic, dynamic>)['photos'];
  if (rows is! List) return const <BookingDiagnosticPhoto>[];
  final photos = rows
      .whereType<Map>()
      .map(
          (row) => BookingDiagnosticPhoto.fromJson(row.cast<String, dynamic>()))
      .toList(growable: false);
  if (photos.isNotEmpty) {
    // Signed photo URLs expire after 300 seconds. Refresh before expiry while
    // this provider is still watched by an open booking page.
    final refreshTimer =
        Timer(const Duration(seconds: 240), ref.invalidateSelf);
    ref.onDispose(refreshTimer.cancel);
  }
  return photos;
});
