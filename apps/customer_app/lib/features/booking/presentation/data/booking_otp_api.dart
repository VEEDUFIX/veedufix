import 'package:dio/dio.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking_otp_api.freezed.dart';
part 'booking_otp_api.g.dart';

@freezed
abstract class BookingOtpInfo with _$BookingOtpInfo {
  const factory BookingOtpInfo({
    @Default('') String bookingId,
    @Default('') String otp,
    DateTime? otpExpiresAt,
  }) = _BookingOtpInfo;

  const BookingOtpInfo._();

  factory BookingOtpInfo.fromJson(Map<String, dynamic> json) =>
      _$BookingOtpInfoFromJson(json);
}

@freezed
abstract class BookingOtpDetails with _$BookingOtpDetails {
  const factory BookingOtpDetails({
    @Default('') String bookingId,
    @Default('') String bookingCode,
    @Default('Service booking') String serviceName,
    @Default('Customer') String customerName,
    @Default('Your professional') String workerName,
    String? workerPhotoUrl,
    String? locationLabel,
    String? statusLabel,
    @Default(<String>[]) List<String> afterPhotoUrls,
  }) = _BookingOtpDetails;

  const BookingOtpDetails._();

  factory BookingOtpDetails.fallback(String bookingId) {
    return BookingOtpDetails(
      bookingId: bookingId,
      bookingCode: bookingId,
    );
  }

  factory BookingOtpDetails.fromJson(Map<String, dynamic> json) {
    // The backend wraps details in a 'booking' object for the GET /bookings/:id endpoint.
    final booking = json['booking'] as Map<String, dynamic>? ?? json;
    final worker = booking['worker'] as Map<String, dynamic>? ?? {};

    return BookingOtpDetails(
      bookingId: (booking['id'] ?? booking['bookingId'] ?? '').toString(),
      bookingCode: (booking['code'] ?? booking['bookingCode'] ?? '').toString(),
      serviceName: (booking['serviceName'] ?? 'Service booking').toString(),
      customerName: (booking['customerName'] ?? 'Customer').toString(),
      workerName: (worker['name'] ?? worker['fullName'] ?? 'Your professional').toString(),
      workerPhotoUrl: (worker['avatarUrl'] ?? worker['photoUrl'])?.toString(),
      locationLabel: (booking['addressLabel'] ?? booking['locationLabel'])?.toString(),
      statusLabel: booking['status']?.toString(),
      afterPhotoUrls: (booking['afterPhotos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class BookingOtpApi {
  BookingOtpApi(this._dio);

  final Dio _dio;

  Future<BookingOtpDetails> fetchDetails(String bookingId) async {
    final response = await _dio.get<Map<String, dynamic>>('/bookings/$bookingId');
    return BookingOtpDetails.fromJson(response.data!);
  }

  Future<BookingOtpInfo> fetchArrivalOtp(String bookingId) async {
    final response = await _dio.get<Map<String, dynamic>>('/bookings/$bookingId/arrival-otp');
    return BookingOtpInfo.fromJson(response.data!);
  }

  Future<BookingOtpInfo> fetchCompletionOtp(String bookingId) async {
    final response = await _dio.get<Map<String, dynamic>>('/bookings/$bookingId/completion-otp');
    return BookingOtpInfo.fromJson(response.data!);
  }

  Future<void> submitRating({
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    await _dio.post<dynamic>(
      '/bookings/$bookingId/rating',
      data: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
  }
}
