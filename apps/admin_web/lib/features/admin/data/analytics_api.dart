import 'package:dio/dio.dart';

class DailyTrendPoint {
  const DailyTrendPoint({
    required this.date,
    required this.revenue,
    required this.commission,
    required this.bookings,
    required this.newWorkers,
  });

  final String date;
  final double revenue;
  final double commission;
  final int bookings;
  final int newWorkers;

  factory DailyTrendPoint.fromJson(Map<String, dynamic> json) {
    return DailyTrendPoint(
      date: json['date'] as String,
      revenue: (json['revenue'] as num).toDouble(),
      commission: (json['commission'] as num? ?? 0).toDouble(),
      bookings: (json['bookings'] as num).toInt(),
      newWorkers: (json['newWorkers'] as num).toInt(),
    );
  }
}

class AnalyticsBreakdownItem {
  const AnalyticsBreakdownItem({
    required this.label,
    required this.bookings,
    required this.revenue,
  });

  final String label;
  final int bookings;
  final double revenue;

  factory AnalyticsBreakdownItem.fromJson(Map<String, dynamic> json) {
    return AnalyticsBreakdownItem(
      label: json['label'] as String? ?? 'Unknown',
      bookings: (json['bookings'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AnalyticsInsights {
  const AnalyticsInsights({
    required this.byCity,
    required this.byCategory,
  });

  final List<AnalyticsBreakdownItem> byCity;
  final List<AnalyticsBreakdownItem> byCategory;

  factory AnalyticsInsights.fromJson(Map<String, dynamic> json) {
    List<AnalyticsBreakdownItem> decodeList(dynamic value) {
      return (value as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsBreakdownItem.fromJson)
          .toList(growable: false);
    }

    return AnalyticsInsights(
      byCity: decodeList(json['byCity']),
      byCategory: decodeList(json['byCategory']),
    );
  }
}

class AnalyticsPayload {
  const AnalyticsPayload({
    required this.trends,
    required this.insights,
    required this.activeBookings,
  });

  final List<DailyTrendPoint> trends;
  final AnalyticsInsights insights;
  final int activeBookings;

  factory AnalyticsPayload.fromJson(Map<String, dynamic> json) {
    final trends = (json['trends'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DailyTrendPoint.fromJson)
        .toList(growable: false);
    final insights = AnalyticsInsights.fromJson(
        json['insights'] as Map<String, dynamic>? ?? const {});
    return AnalyticsPayload(
      trends: trends,
      insights: insights,
      activeBookings: (json['activeBookings'] as num? ?? 0).toInt(),
    );
  }
}

class AnalyticsApi {
  AnalyticsApi(this._dio);

  final Dio _dio;

  Future<AnalyticsPayload> fetchTrends({int days = 30}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/admin/analytics/trends',
      queryParameters: {'days': days},
    );

    return AnalyticsPayload.fromJson(
        response.data ?? const <String, dynamic>{});
  }
}
