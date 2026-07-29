import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/booking_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

export '../../domain/entities/booking_summary.dart';

final bookingDetailProvider =
    FutureProvider.autoDispose.family<BookingSummary, String>((ref, bookingId) async {
  final apiClient = ref.watch(apiClientProvider);
  final response =
      await apiClient.get('/users/bookings/$bookingId/summary');
  return BookingSummary.fromJson(response);
});
