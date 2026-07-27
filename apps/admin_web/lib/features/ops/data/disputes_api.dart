import 'package:dio/dio.dart';

class DisputeQueueItem {
  const DisputeQueueItem({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.customerName,
    required this.workerName,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.resolutionNote,
    required this.resolvedAt,
    required this.resolvedBy,
    required this.refundId,
  });

  final String id;
  final String bookingId;
  final String bookingCode;
  final String customerName;
  final String? workerName;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? refundId;

  factory DisputeQueueItem.fromJson(Map<String, dynamic> json) {
    final booking = (json['booking'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final customer = (booking['customer'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final worker = (booking['worker'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return DisputeQueueItem(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? booking['id'] as String? ?? '',
      bookingCode: booking['code'] as String? ?? '',
      customerName: customer['name'] as String? ?? 'Customer',
      workerName: _resolveWorkerName(worker),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      resolutionNote: json['resolutionNote'] as String?,
      resolvedAt: _parseDateTime(json['resolvedAt']),
      resolvedBy: json['resolvedBy'] as String?,
      refundId: json['refundId'] as String?,
    );
  }
}

class DisputeChecklistItem {
  const DisputeChecklistItem({
    required this.label,
    required this.complete,
  });

  final String label;
  final bool complete;

  factory DisputeChecklistItem.fromJson(dynamic value, int index) {
    if (value is String) {
      return DisputeChecklistItem(
        label: value.trim().isEmpty ? 'Item ${index + 1}' : value.trim(),
        complete: value.trim().isNotEmpty,
      );
    }

    if (value is Map) {
      final json = value.cast<String, dynamic>();
      final label = (json['label'] as String?)?.trim().isNotEmpty == true
          ? (json['label'] as String).trim()
          : 'Item ${index + 1}';
      final complete = json['complete'] as bool? ??
          json['checked'] as bool? ??
          json['done'] as bool? ??
          json['isComplete'] as bool? ??
          false;

      return DisputeChecklistItem(label: label, complete: complete);
    }

    return DisputeChecklistItem(
        label: 'Item ${index + 1}', complete: value != null);
  }
}

class DisputeEvidenceBooking {
  const DisputeEvidenceBooking({
    required this.id,
    required this.code,
    required this.totalAmount,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerNotes,
    required this.workerName,
    required this.workerAvatarUrl,
    required this.cityName,
    required this.citySlug,
    required this.jobStatus,
    required this.completedAt,
    required this.beforePhotos,
    required this.afterPhotos,
    required this.checklist,
  });

  final String id;
  final String code;
  final double totalAmount;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerNotes;
  final String? workerName;
  final String? workerAvatarUrl;
  final String cityName;
  final String citySlug;
  final String? jobStatus;
  final DateTime? completedAt;
  final List<String> beforePhotos;
  final List<String> afterPhotos;
  final List<DisputeChecklistItem> checklist;

  factory DisputeEvidenceBooking.fromJson(Map<String, dynamic> json) {
    final city = (json['city'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final customer = (json['customer'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final worker = (json['worker'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final jobExecution =
        (json['jobExecution'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    return DisputeEvidenceBooking(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      customerName: customer['name'] as String? ?? 'Customer',
      customerEmail: customer['email'] as String?,
      customerPhone: customer['phone'] as String?,
      customerNotes: json['customerNotes'] as String?,
      workerName: _resolveWorkerName(worker),
      workerAvatarUrl: _resolveWorkerAvatar(worker),
      cityName: city['name'] as String? ?? '',
      citySlug: city['slug'] as String? ?? '',
      jobStatus: jobExecution['status'] as String?,
      completedAt: _parseDateTime(jobExecution['completedAt']),
      beforePhotos: (jobExecution['beforePhotos'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      afterPhotos: (jobExecution['afterPhotos'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      checklist: (jobExecution['checklist'] as List? ?? const [])
          .mapIndexed(DisputeChecklistItem.fromJson)
          .toList(growable: false),
    );
  }
}

class DisputeEvidence {
  const DisputeEvidence({
    required this.dispute,
    required this.booking,
  });

  final DisputeQueueItem dispute;
  final DisputeEvidenceBooking booking;

  factory DisputeEvidence.fromJson(Map<String, dynamic> json) {
    return DisputeEvidence(
      dispute: DisputeQueueItem.fromJson(
          json['dispute'] as Map<String, dynamic>? ??
              const <String, dynamic>{}),
      booking: DisputeEvidenceBooking.fromJson(
          json['booking'] as Map<String, dynamic>? ??
              const <String, dynamic>{}),
    );
  }
}

class DisputeQueueResponse {
  const DisputeQueueResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<DisputeQueueItem> items;
  final int total;
  final int page;
  final int pageSize;

  factory DisputeQueueResponse.fromJson(Map<String, dynamic> json) {
    return DisputeQueueResponse(
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DisputeQueueItem.fromJson)
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );
  }
}

class DisputeResolutionResult {
  const DisputeResolutionResult({
    required this.id,
    required this.status,
    required this.resolutionNote,
    required this.resolvedBy,
    required this.resolvedAt,
    required this.refundId,
  });

  final String id;
  final String status;
  final String? resolutionNote;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? refundId;

  factory DisputeResolutionResult.fromJson(Map<String, dynamic> json) {
    return DisputeResolutionResult(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      resolutionNote: json['resolutionNote'] as String?,
      resolvedBy: json['resolvedBy'] as String?,
      resolvedAt: _parseDateTime(json['resolvedAt']),
      refundId: json['refundId'] as String?,
    );
  }
}

class DisputesApi {
  DisputesApi(this._dio);

  final Dio _dio;

  Future<DisputeQueueResponse> fetchQueue({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/disputes',
      queryParameters: {
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return DisputeQueueResponse.fromJson(
        response.data ?? const <String, dynamic>{});
  }

  Future<DisputeEvidence> fetchDispute(String disputeId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/admin/disputes/$disputeId');
    return DisputeEvidence.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<DisputeResolutionResult> resolveDispute(
    String disputeId, {
    required String resolution,
    required String note,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/disputes/$disputeId/resolve',
      data: {
        'resolution': resolution,
        'note': note,
      },
    );
    return DisputeResolutionResult.fromJson(
        response.data ?? const <String, dynamic>{});
  }
}

String? _resolveWorkerName(Map<String, dynamic> worker) {
  final fullName = worker['fullName'] as String?;
  if (fullName != null && fullName.trim().isNotEmpty) {
    return fullName.trim();
  }

  final displayName = worker['displayName'] as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }

  final user = (worker['user'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};
  final name = user['name'] as String?;
  return name != null && name.trim().isNotEmpty ? name.trim() : null;
}

String? _resolveWorkerAvatar(Map<String, dynamic> worker) {
  final user = (worker['user'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};
  final avatarUrl = user['avatarUrl'] as String?;
  return avatarUrl != null && avatarUrl.trim().isNotEmpty
      ? avatarUrl.trim()
      : null;
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

extension on List<dynamic> {
  Iterable<T> mapIndexed<T>(
      T Function(dynamic value, int index) converter) sync* {
    for (var i = 0; i < length; i++) {
      yield converter(this[i], i);
    }
  }
}
