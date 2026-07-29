import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/coupon_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

export '../../data/models/coupon_model.dart';

final couponsProvider = FutureProvider.autoDispose<List<CouponModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/catalog/coupons');
  final items = response['coupons'] as List<dynamic>? ?? [];
  return items
      .whereType<Map<String, dynamic>>()
      .map(CouponModel.fromJson)
      .toList(growable: false);
});
