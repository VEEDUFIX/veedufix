import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(ref.watch(apiClientProvider));
});

abstract class PaymentRepository {
  Future<String> getOrderStatus({
    required String bookingId,
    required String razorpayOrderId,
  });

  Future<Map<String, dynamic>> createOrder({
    required String cityId,
    required List<Map<String, dynamic>> items,
    String? couponCode,
    required String bookingType,
    required String scheduledFor,
  });

  Future<Map<String, dynamic>> verifyPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });
}

class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<String> getOrderStatus({
    required String bookingId,
    required String razorpayOrderId,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/payments/order-status/$bookingId/$razorpayOrderId',
    );
    final status = response.data?['status'];
    if (status is! String || status.isEmpty) {
      throw const FormatException('Payment status response is invalid');
    }
    return status;
  }

  @override
  Future<Map<String, dynamic>> createOrder({
    required String cityId,
    required List<Map<String, dynamic>> items,
    String? couponCode,
    required String bookingType,
    required String scheduledFor,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/payments/create-razorpay-order',
      data: {
        'cityId': cityId,
        'items': items,
        'couponCode': couponCode,
        'bookingType': bookingType,
        'scheduledFor': scheduledFor,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> verifyPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/payments/verify-payment',
      data: {
        'bookingId': bookingId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
    return response.data ?? <String, dynamic>{};
  }
}
