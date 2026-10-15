import 'package:marketplace_shared/marketplace_shared.dart';

class CustomQuoteApi {
  const CustomQuoteApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> respond(
    String bookingId, {
    required bool accept,
  }) => _client.post(
    '/bookings/$bookingId/custom-quote/respond',
    data: {'accept': accept},
  );

  Future<Map<String, dynamic>> createPaymentOrder(String bookingId) =>
      _client.post('/bookings/$bookingId/custom-quote/payment-order');

  Future<Map<String, dynamic>> verifyPayment(
    String bookingId, {
    required String orderId,
    required String paymentId,
    required String signature,
  }) => _client.post(
    '/bookings/$bookingId/custom-quote/verify-payment',
    data: {
      'razorpayOrderId': orderId,
      'razorpayPaymentId': paymentId,
      'razorpaySignature': signature,
    },
  );

  Future<Map<String, dynamic>> getQuote(String bookingId) =>
      _client.get('/bookings/$bookingId/custom-quote');
}
