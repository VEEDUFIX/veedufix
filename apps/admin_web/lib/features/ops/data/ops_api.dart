import 'package:dio/dio.dart';

class OpsSummaryCounts {
  const OpsSummaryCounts({
    required this.activeJobsCount,
    required this.dispatchFailuresCount,
    required this.openDisputesCount,
    required this.failedPayoutsCount,
    required this.failedRefundsCount,
    required this.pendingWorkerReviewsCount,
    required this.totalRevenue,
    required this.totalBookings,
    required this.completedBookings,
    required this.todaysNewWorkers,
  });

  final int activeJobsCount;
  final int dispatchFailuresCount;
  final int openDisputesCount;
  final int failedPayoutsCount;
  final int failedRefundsCount;
  final int pendingWorkerReviewsCount;
  final double totalRevenue;
  final int totalBookings;
  final int completedBookings;
  final int todaysNewWorkers;

  factory OpsSummaryCounts.fromJson(Map<String, dynamic> json) {
    return OpsSummaryCounts(
      activeJobsCount: (json['activeJobsCount'] as num?)?.toInt() ?? 0,
      dispatchFailuresCount: (json['dispatchFailuresCount'] as num?)?.toInt() ?? 0,
      openDisputesCount: (json['openDisputesCount'] as num?)?.toInt() ?? 0,
      failedPayoutsCount: (json['failedPayoutsCount'] as num?)?.toInt() ?? 0,
      failedRefundsCount: (json['failedRefundsCount'] as num?)?.toInt() ?? 0,
      pendingWorkerReviewsCount: (json['pendingWorkerReviewsCount'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      completedBookings: (json['completedBookings'] as num?)?.toInt() ?? 0,
      todaysNewWorkers: (json['todaysNewWorkers'] as num?)?.toInt() ?? 0,
    );
  }
}

class OpsChecklistItem {
  const OpsChecklistItem({
    required this.label,
    required this.complete,
  });

  final String label;
  final bool complete;

  factory OpsChecklistItem.fromJson(Map<String, dynamic> json) {
    return OpsChecklistItem(
      label: json['label'] as String? ?? 'Checklist item',
      complete: json['complete'] as bool? ?? false,
    );
  }
}

class OpsLiveJob {
  const OpsLiveJob({
    required this.bookingId,
    required this.bookingCode,
    required this.bookingStatus,
    required this.customerName,
    required this.customerAvatarUrl,
    required this.workerName,
    required this.workerAvatarUrl,
    required this.cityName,
    required this.serviceCategories,
    required this.status,
    required this.scheduledAt,
    required this.assignedAt,
    required this.elapsedMinutes,
    required this.beforePhotos,
    required this.afterPhotos,
    required this.checklistItems,
    required this.notes,
    required this.customerNotes,
    required this.workerLat,
    required this.workerLng,
    required this.updatedAt,
  });

  final String bookingId;
  final String bookingCode;
  final String bookingStatus;
  final String customerName;
  final String? customerAvatarUrl;
  final String? workerName;
  final String? workerAvatarUrl;
  final String cityName;
  final List<String> serviceCategories;
  final String status;
  final DateTime scheduledAt;
  final DateTime assignedAt;
  final int elapsedMinutes;
  final List<String> beforePhotos;
  final List<String> afterPhotos;
  final List<OpsChecklistItem> checklistItems;
  final String? notes;
  final String? customerNotes;
  final double? workerLat;
  final double? workerLng;
  final DateTime updatedAt;

  bool get isNoShowRisk => status == 'assigned' && DateTime.now().isAfter(scheduledAt.add(const Duration(minutes: 20)));

  factory OpsLiveJob.fromJson(Map<String, dynamic> json) {
    return OpsLiveJob(
      bookingId: json['bookingId'] as String? ?? '',
      bookingCode: json['bookingCode'] as String? ?? '',
      bookingStatus: json['bookingStatus'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Customer',
      customerAvatarUrl: json['customerAvatarUrl'] as String?,
      workerName: json['workerName'] as String?,
      workerAvatarUrl: json['workerAvatarUrl'] as String?,
      cityName: json['cityName'] as String? ?? '',
      serviceCategories: (json['serviceCategories'] as List? ?? const []).whereType<String>().toList(growable: false),
      status: json['status'] as String? ?? 'assigned',
      scheduledAt: _parseDateTime(json['scheduledAt']) ?? DateTime.now(),
      assignedAt: _parseDateTime(json['assignedAt']) ?? DateTime.now(),
      elapsedMinutes: (json['elapsedMinutes'] as num?)?.toInt() ?? 0,
      beforePhotos: (json['beforePhotos'] as List? ?? const []).whereType<String>().toList(growable: false),
      afterPhotos: (json['afterPhotos'] as List? ?? const []).whereType<String>().toList(growable: false),
      checklistItems: (json['checklistItems'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpsChecklistItem.fromJson)
          .toList(growable: false),
      notes: json['notes'] as String?,
      customerNotes: json['customerNotes'] as String?,
      workerLat: (json['workerLat'] as num?)?.toDouble(),
      workerLng: (json['workerLng'] as num?)?.toDouble(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class OpsAlert {
  const OpsAlert({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.sourceId,
    required this.bookingId,
    required this.bookingCode,
    required this.customerName,
    required this.amount,
    required this.createdAt,
    required this.retryAvailable,
  });

  final String id;
  final String kind;
  final String title;
  final String message;
  final String? sourceId;
  final String? bookingId;
  final String? bookingCode;
  final String? customerName;
  final double? amount;
  final DateTime createdAt;
  final bool retryAvailable;

  factory OpsAlert.fromJson(Map<String, dynamic> json) {
    return OpsAlert(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'dispatch_failure',
      title: json['title'] as String? ?? 'Alert',
      message: json['message'] as String? ?? '',
      sourceId: json['sourceId'] as String?,
      bookingId: json['bookingId'] as String?,
      bookingCode: json['bookingCode'] as String?,
      customerName: json['customerName'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      retryAvailable: json['retryAvailable'] as bool? ?? false,
    );
  }

  bool get isDispatchFailure => kind == 'dispatch_failure';
  bool get isPayoutFailure => kind == 'payout_failure';
  bool get isRefundFailure => kind == 'refund_failure';
  bool get isPaymentMismatch => kind == 'payment_mismatch';
}

class OpsOverviewSnapshot {
  const OpsOverviewSnapshot({
    required this.summary,
    required this.liveJobs,
    required this.alerts,
  });

  final OpsSummaryCounts summary;
  final List<OpsLiveJob> liveJobs;
  final List<OpsAlert> alerts;

  factory OpsOverviewSnapshot.fromJson(Map<String, dynamic> json) {
    return OpsOverviewSnapshot(
      summary: OpsSummaryCounts.fromJson((json['summary'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      liveJobs: (json['liveJobs'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpsLiveJob.fromJson)
          .toList(growable: false),
      alerts: (json['alerts'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpsAlert.fromJson)
          .toList(growable: false),
    );
  }
}

class OpsApi {
  OpsApi(this._dio);

  final Dio _dio;

  Future<OpsOverviewSnapshot> fetchOverview() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/ops/summary');
    return OpsOverviewSnapshot.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<void> redispatchBooking(String bookingId) async {
    await _dio.post('/bookings/$bookingId/dispatch', data: const {});
  }

  Future<void> retryPayout(String payoutId) async {
    await _dio.post('/admin/payouts/$payoutId/retry', data: const {});
  }

  Future<void> retryRefund(String refundId) async {
    await _dio.post('/admin/refunds/$refundId/retry', data: const {});
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String formatDurationLabel(Duration duration) {
  if (duration.inMinutes < 1) {
    return 'just now';
  }
  if (duration.inMinutes < 60) {
    return '${duration.inMinutes}m';
  }
  if (duration.inHours < 24) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  return hours == 0 ? '${days}d' : '${days}d ${hours}h';
}

extension OpsLiveJobFormatting on OpsLiveJob {
  String get serviceLabel => serviceCategories.isEmpty ? 'No category' : serviceCategories.join(', ');

  String get elapsedLabel => formatDurationLabel(Duration(minutes: elapsedMinutes));

  String get statusLabel => status.replaceAll('_', ' ');
}
