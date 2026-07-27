import 'package:dio/dio.dart';

class BookingOtpInfo {
  const BookingOtpInfo({
    required this.bookingId,
    required this.otp,
    this.otpExpiresAt,
  });

  final String bookingId;
  final String otp;
  final DateTime? otpExpiresAt;

  factory BookingOtpInfo.fromJson(dynamic json) {
    final map = _asMap(json);
    return BookingOtpInfo(
      bookingId: _stringValue(map['bookingId']) ?? '',
      otp: _stringValue(map['otp']) ?? '',
      otpExpiresAt: _dateValue(map['otpExpiresAt']),
    );
  }
}

class BookingOtpDetails {
  const BookingOtpDetails({
    required this.bookingId,
    required this.bookingCode,
    required this.serviceName,
    required this.customerName,
    required this.workerName,
    required this.afterPhotoUrls,
    this.workerPhotoUrl,
    this.locationLabel,
    this.statusLabel,
  });

  final String bookingId;
  final String bookingCode;
  final String serviceName;
  final String customerName;
  final String workerName;
  final String? workerPhotoUrl;
  final String? locationLabel;
  final String? statusLabel;
  final List<String> afterPhotoUrls;

  factory BookingOtpDetails.fallback(String bookingId) {
    return BookingOtpDetails(
      bookingId: bookingId,
      bookingCode: bookingId,
      serviceName: 'Service booking',
      customerName: 'Customer',
      workerName: 'Your professional',
      afterPhotoUrls: const <String>[],
    );
  }

  factory BookingOtpDetails.fromJson(String bookingId, dynamic json) {
    final map = _asMap(json);
    final booking = _asMap(map['booking']);
    final data = _asMap(map['data']);
    final details = _asMap(map['details']);
    final execution = _asMap(map['jobExecution']);
    final worker = _asMap(map['worker']);
    final workerUser = _asMap(worker['user']);
    final service = _asMap(map['service']);
    final customer = _asMap(map['customer']);

    final afterPhotoUrls = _listOfStrings([
      map['afterPhotos'],
      booking['afterPhotos'],
      details['afterPhotos'],
      data['afterPhotos'],
      execution['afterPhotos'],
      execution['photos'],
    ]);

    final resolvedWorker = _firstString([
      worker['name'],
      workerUser['name'],
      map['workerName'],
      booking['workerName'],
      data['workerName'],
      details['workerName'],
      'Your professional',
    ])!;

    return BookingOtpDetails(
      bookingId: _firstString([
            map['bookingId'],
            booking['id'],
            bookingId,
            data['bookingId'],
            details['bookingId'],
            execution['bookingId'],
          ]) ??
          bookingId,
      bookingCode: _firstString([
            map['bookingCode'],
            booking['bookingCode'],
            data['bookingCode'],
            details['bookingCode'],
          ]) ??
          bookingId,
      serviceName: _firstString([
            service['name'],
            map['serviceName'],
            booking['serviceName'],
            data['serviceName'],
            details['serviceName'],
            'Service booking',
          ]) ??
          'Service booking',
      customerName: _firstString([
            customer['name'],
            map['customerName'],
            booking['customerName'],
            data['customerName'],
            details['customerName'],
            'Customer',
          ]) ??
          'Customer',
      workerName: resolvedWorker,
      workerPhotoUrl: _firstString([
        worker['photoUrl'],
        worker['avatarUrl'],
        worker['profilePhotoUrl'],
        workerUser['photoUrl'],
        workerUser['avatarUrl'],
        map['workerPhotoUrl'],
        booking['workerPhotoUrl'],
        data['workerPhotoUrl'],
        details['workerPhotoUrl'],
      ]),
      locationLabel: _firstString([
        booking['locationLabel'],
        booking['location'],
        map['locationLabel'],
        data['locationLabel'],
        details['locationLabel'],
      ]),
      statusLabel: _firstString([
        map['status'],
        booking['status'],
        data['status'],
        details['status'],
      ]),
      afterPhotoUrls: afterPhotoUrls,
    );
  }
}

class BookingOtpApi {
  BookingOtpApi(this._dio);

  final Dio _dio;

  Future<BookingOtpDetails> fetchDetails(String bookingId) async {
    try {
      final response = await _dio.get<dynamic>('/bookings/$bookingId');
      return BookingOtpDetails.fromJson(bookingId, response.data);
    } catch (_) {
      return BookingOtpDetails.fallback(bookingId);
    }
  }

  Future<BookingOtpInfo> fetchArrivalOtp(String bookingId) async {
    final response = await _dio.get<dynamic>('/bookings/$bookingId/arrival-otp');
    return BookingOtpInfo.fromJson(response.data);
  }

  Future<BookingOtpInfo> fetchCompletionOtp(String bookingId) async {
    final response = await _dio.get<dynamic>('/bookings/$bookingId/completion-otp');
    return BookingOtpInfo.fromJson(response.data);
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

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}

String? _firstString(Iterable<dynamic> values) {
  for (final value in values) {
    final text = _stringValue(value);
    if (text != null) {
      return text;
    }
  }
  return null;
}

List<String> _listOfStrings(Iterable<dynamic> values) {
  final result = <String>[];
  for (final value in values) {
    if (value is List) {
      for (final item in value) {
        final text = _stringValue(item);
        if (text != null) {
          result.add(text);
        }
      }
    }
  }
  return result;
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

DateTime? _dateValue(dynamic value) {
  final text = _stringValue(value);
  if (text == null) {
    return null;
  }
  return DateTime.tryParse(text);
}
