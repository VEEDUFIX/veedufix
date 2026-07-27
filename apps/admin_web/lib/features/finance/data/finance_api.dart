import 'package:dio/dio.dart';

class FinancePayoutQueueResponse {
  const FinancePayoutQueueResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<FinancePayoutItem> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory FinancePayoutQueueResponse.fromJson(Map<String, dynamic> json) {
    return FinancePayoutQueueResponse(
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FinancePayoutItem.fromJson)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class FinancePayoutItem {
  const FinancePayoutItem({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.workerName,
    required this.amount,
    required this.commissionAmount,
    required this.status,
    required this.createdAt,
    required this.failureReason,
  });

  final String id;
  final String bookingId;
  final String bookingCode;
  final String? workerName;
  final double amount;
  final double commissionAmount;
  final String status;
  final DateTime createdAt;
  final String? failureReason;

  factory FinancePayoutItem.fromJson(Map<String, dynamic> json) {
    final booking = (json['booking'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final worker = (booking['worker'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return FinancePayoutItem(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? booking['id'] as String? ?? '',
      bookingCode: booking['code'] as String? ?? '',
      workerName: _resolveWorkerName(worker),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      failureReason: json['failureReason'] as String?,
    );
  }
}

class FinanceRefundQueueResponse {
  const FinanceRefundQueueResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<FinanceRefundItem> items;
  final int page;
  final int pageSize;
  final int total;

  factory FinanceRefundQueueResponse.fromJson(Map<String, dynamic> json) {
    return FinanceRefundQueueResponse(
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FinanceRefundItem.fromJson)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class FinanceRefundItem {
  const FinanceRefundItem({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.customerName,
    required this.amount,
    required this.reason,
    required this.status,
    required this.razorpayRefundId,
    required this.failureReason,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String bookingCode;
  final String? customerName;
  final double amount;
  final String reason;
  final String status;
  final String? razorpayRefundId;
  final String? failureReason;
  final DateTime createdAt;

  factory FinanceRefundItem.fromJson(Map<String, dynamic> json) {
    final booking = (json['booking'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final customer = (booking['customer'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return FinanceRefundItem(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? booking['id'] as String? ?? '',
      bookingCode: booking['code'] as String? ?? '',
      customerName: customer['name'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      razorpayRefundId: json['razorpayRefundId'] as String?,
      failureReason: json['failureReason'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class FinanceApi {
  FinanceApi(this._dio);

  final Dio _dio;

  Future<FinancePayoutQueueResponse> fetchPayouts({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/payouts',
      queryParameters: {
        if (status != null && status.isNotEmpty && status != 'all') 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    return FinancePayoutQueueResponse.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<FinanceRefundQueueResponse> fetchRefunds({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/refunds',
      queryParameters: {
        if (status != null && status.isNotEmpty && status != 'all') 'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return FinanceRefundQueueResponse.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<void> retryPayout(String payoutId) async {
    await _dio.post('/admin/payouts/$payoutId/retry', data: const {});
  }

  Future<void> retryRefund(String refundId) async {
    await _dio.post('/admin/refunds/$refundId/retry', data: const {});
  }
}

String? _resolveWorkerName(Map<String, dynamic> worker) {
  final fullName = worker['fullName'] as String?;
  if (fullName != null && fullName.trim().isNotEmpty) {
    return fullName.trim();
  }

  final user = (worker['user'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  final name = user['name'] as String?;
  return name != null && name.trim().isNotEmpty ? name.trim() : null;
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
