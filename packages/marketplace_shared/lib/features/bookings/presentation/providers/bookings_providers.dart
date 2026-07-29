import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/booking_entities.dart';

export '../../domain/entities/booking_entities.dart';

// status: 'upcoming' | 'completed' | 'cancelled'
final customerBookingsProvider =
    FutureProvider.autoDispose.family<List<CustomerBooking>, String>((ref, status) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/users/me/bookings?status=$status');
  final list = response['bookings'] as List<dynamic>? ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(CustomerBooking.fromJson)
      .toList(growable: false);
});
