class WorkerJob {
  const WorkerJob({
    required this.bookingId,
    required this.code,
    required this.status,
    required this.scheduledAt,
    required this.totalAmount,
    this.serviceId,
    required this.serviceName,
    this.serviceIcon,
    this.addressLabel,
    this.cityName,
    this.destinationQuery,
    this.destinationLatitude,
    this.destinationLongitude,
    this.customerName,
    this.customerAvatarUrl,
    // For incoming jobs only:
    this.offerId,
    this.expiresAt,
  });

  final String bookingId;
  final String code;
  final String status;
  final DateTime scheduledAt;
  final double totalAmount;
  final String? serviceId;
  final String serviceName;
  final String? serviceIcon;
  final String? addressLabel;
  final String? cityName;
  final String? destinationQuery;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? customerName;
  final String? customerAvatarUrl;
  final String? offerId;
  final DateTime? expiresAt;

  factory WorkerJob.fromJson(Map<String, dynamic> json) => WorkerJob(
        bookingId: json['bookingId'] as String? ?? '',
        code: json['code'] as String? ?? '',
        status: json['status'] as String? ?? '',
        scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ?? DateTime.now(),
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        serviceId: json['serviceId'] as String?,
        serviceName: json['serviceName'] as String? ?? 'Service',
        serviceIcon: json['serviceIcon'] as String?,
        addressLabel: json['addressLabel'] as String?,
        cityName: json['cityName'] as String?,
        destinationQuery: json['destinationQuery'] as String?,
        destinationLatitude: _doubleValue([
          json['destinationLatitude'],
          json['addressLatitude'],
          json['lat'],
        ]),
        destinationLongitude: _doubleValue([
          json['destinationLongitude'],
          json['addressLongitude'],
          json['lng'],
          json['lon'],
        ]),
        customerName: json['customerName'] as String?,
        customerAvatarUrl: json['customerAvatarUrl'] as String?,
        offerId: json['offerId'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
      );
}

double? _doubleValue(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

class WorkerDashboardStats {
  const WorkerDashboardStats({
    required this.completedJobsCount,
    required this.averageRating,
    required this.monthlyEarnings,
    required this.isAvailable,
    this.todayJobs = const [],
  });

  final int completedJobsCount;
  final double averageRating;
  final double monthlyEarnings;
  final bool isAvailable;
  final List<WorkerJob> todayJobs;

  factory WorkerDashboardStats.fromJson(Map<String, dynamic> json) {
    List<T> decodeList<T>(dynamic val, T Function(Map<String, dynamic>) builder) {
      if (val is! List) return <T>[];
      return val.whereType<Map<String, dynamic>>().map(builder).toList(growable: false);
    }
    return WorkerDashboardStats(
      completedJobsCount: (json['completedJobsCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      monthlyEarnings: (json['monthlyEarnings'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] as bool? ?? false,
      todayJobs: decodeList(json['todayJobs'], WorkerJob.fromJson),
    );
  }
}
