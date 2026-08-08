// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_otp_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookingOtpInfo _$BookingOtpInfoFromJson(Map<String, dynamic> json) =>
    _BookingOtpInfo(
      bookingId: json['bookingId'] as String? ?? '',
      otp: json['otp'] as String? ?? '',
      otpExpiresAt: json['otpExpiresAt'] == null
          ? null
          : DateTime.parse(json['otpExpiresAt'] as String),
    );

Map<String, dynamic> _$BookingOtpInfoToJson(_BookingOtpInfo instance) =>
    <String, dynamic>{
      'bookingId': instance.bookingId,
      'otp': instance.otp,
      'otpExpiresAt': instance.otpExpiresAt?.toIso8601String(),
    };
