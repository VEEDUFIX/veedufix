import 'package:dio/dio.dart';

class DailyTrendPoint {
  const DailyTrendPoint({
    required this.date,
    required this.revenue,
    required this.bookings,
    required this.newWorkers,
  });

  final String date;
  final double revenue;
  final int bookings;
  final int newWorkers;

  factory DailyTrendPoint.fromJson(Map<String, dynamic> json) {
    return DailyTrendPoint(
      date: json['date'] as String,
      revenue: (json['revenue'] as num).toDouble(),
      bookings: (json['bookings'] as num).toInt(),
      newWorkers: (json['newWorkers'] as num).toInt(),
    );
  }
}

class AnalyticsApi {
  AnalyticsApi(this._dio);

  final Dio _dio;

  Future<List<DailyTrendPoint>> fetchTrends({int days = 30}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/admin/analytics/trends',
      queryParameters: {'days': days},
    );

    final data = response.data?['trends'] as List?;
    if (data == null) {
      return [];
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(DailyTrendPoint.fromJson)
        .toList();
  }
}
