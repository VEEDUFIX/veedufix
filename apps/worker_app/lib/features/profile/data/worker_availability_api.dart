import 'package:dio/dio.dart';

class WeeklyAvailabilitySlot {
  const WeeklyAvailabilitySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  final int dayOfWeek;
  final String startTime;
  final String endTime;

  factory WeeklyAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return WeeklyAvailabilitySlot(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      startTime: json['startTime'] as String? ?? '09:00',
      endTime: json['endTime'] as String? ?? '18:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

class WorkerAvailabilityApi {
  WorkerAvailabilityApi(this._dio);

  final Dio _dio;

  Future<List<WeeklyAvailabilitySlot>> getAvailability() async {
    final response = await _dio.get<Map<String, dynamic>>('/worker/availability');
    final data = response.data ?? <String, dynamic>{};
    final slots = data['slots'];
    if (slots is! List) {
      return <WeeklyAvailabilitySlot>[];
    }
    return slots
        .whereType<Map>()
        .map((item) => WeeklyAvailabilitySlot.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<WeeklyAvailabilitySlot>> setAvailability(List<WeeklyAvailabilitySlot> slots) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/worker/availability',
      data: {
        'slots': slots.map((slot) => slot.toJson()).toList(growable: false),
      },
    );
    final data = response.data ?? <String, dynamic>{};
    final nextSlots = data['slots'];
    if (nextSlots is! List) {
      return <WeeklyAvailabilitySlot>[];
    }
    return nextSlots
        .whereType<Map>()
        .map((item) => WeeklyAvailabilitySlot.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
