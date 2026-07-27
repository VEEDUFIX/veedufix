import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  RazorpayService(this._razorpay);

  factory RazorpayService.create() => RazorpayService(Razorpay());

  final Razorpay _razorpay;

  void registerCallbacks({
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
    required void Function(ExternalWalletResponse response) onExternalWallet,
  }) {
    _razorpay.clear();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  void openCheckout({
    required String keyId,
    required String orderId,
    required String bookingCode,
    required String customerName,
    required String email,
    required String phone,
    required int amountInPaise,
  }) {
    if (keyId.isEmpty) {
      throw StateError('Missing Razorpay key ID.');
    }

    final options = <String, Object?>{
      'key': keyId,
      'amount': amountInPaise,
      'order_id': orderId,
      'name': 'VeeduFix',
      'description': 'Booking $bookingCode',
      'prefill': <String, String>{
        'name': customerName,
        'email': email,
        'contact': phone,
      },
      'theme': <String, String>{'color': '#0F766E'},
    };

    _razorpay.open(options);
  }

  void dispose() {
    _razorpay.clear();
  }
}
