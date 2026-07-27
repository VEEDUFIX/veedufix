import 'package:dio/dio.dart';

class BookingPaymentOrder {
  BookingPaymentOrder({
    required this.keyId,
    required this.bookingId,
    required this.bookingCode,
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
  });

  factory BookingPaymentOrder.fromJson(Map<String, dynamic> json) {
    return BookingPaymentOrder(
      keyId: json['keyId'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      bookingCode: json['bookingCode'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      customerName: json['customerName'] as String? ?? '',
      customerEmail: json['customerEmail'] as String?,
      customerPhone: json['customerPhone'] as String?,
    );
  }

  final String keyId;
  final String bookingId;
  final String bookingCode;
  final String orderId;
  final int amountPaise;
  final String currency;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
}

class BookingPaymentApi {
  BookingPaymentApi(this._dio);

  final Dio _dio;

  Future<BookingPaymentOrder> createOrder({
    required int amountPaise,
    required String description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/create-order',
      data: {
        'amountPaise': amountPaise,
        'description': description,
      },
    );

    return BookingPaymentOrder.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<void> verifyPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    await _dio.post<void>(
      '/payments/verify',
      data: {
        'bookingId': bookingId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
  }
}
