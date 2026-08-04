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

class TaxGstBreakdownItem {
  const TaxGstBreakdownItem({
    required this.sacCode,
    required this.taxableValue,
    required this.gstAmount,
    required this.invoiceCount,
  });

  final String sacCode;
  final double taxableValue;
  final double gstAmount;
  final int invoiceCount;

  factory TaxGstBreakdownItem.fromJson(Map<String, dynamic> json) {
    return TaxGstBreakdownItem(
      sacCode: json['sacCode'] as String? ?? 'PENDING',
      taxableValue: (json['taxableValue'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0,
      invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class TaxGstSummary {
  const TaxGstSummary({
    required this.startDate,
    required this.endDate,
    required this.invoiceCount,
    required this.totalTaxableValue,
    required this.totalGstCollected,
    required this.breakdown,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final int invoiceCount;
  final double totalTaxableValue;
  final double totalGstCollected;
  final List<TaxGstBreakdownItem> breakdown;

  factory TaxGstSummary.fromJson(Map<String, dynamic> json) {
    return TaxGstSummary(
      startDate: _parseDateTime(json['startDate']),
      endDate: _parseDateTime(json['endDate']),
      invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
      totalTaxableValue: (json['totalTaxableValue'] as num?)?.toDouble() ?? 0,
      totalGstCollected: (json['totalGstCollected'] as num?)?.toDouble() ?? 0,
      breakdown: (json['breakdown'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TaxGstBreakdownItem.fromJson)
          .toList(growable: false),
    );
  }
}

class TaxRevenueSummary {
  const TaxRevenueSummary({
    required this.startDate,
    required this.endDate,
    required this.platformCommissionEarned,
    required this.totalGstLiability,
    required this.totalWorkerPayouts,
    required this.payoutCount,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final double platformCommissionEarned;
  final double totalGstLiability;
  final double totalWorkerPayouts;
  final int payoutCount;

  factory TaxRevenueSummary.fromJson(Map<String, dynamic> json) {
    return TaxRevenueSummary(
      startDate: _parseDateTime(json['startDate']),
      endDate: _parseDateTime(json['endDate']),
      platformCommissionEarned: (json['platformCommissionEarned'] as num?)?.toDouble() ?? 0,
      totalGstLiability: (json['totalGstLiability'] as num?)?.toDouble() ?? 0,
      totalWorkerPayouts: (json['totalWorkerPayouts'] as num?)?.toDouble() ?? 0,
      payoutCount: (json['payoutCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class TaxAnnualSummary {
  const TaxAnnualSummary({
    required this.financialYear,
    required this.periodStart,
    required this.periodEnd,
    required this.gstSummary,
    required this.revenueSummary,
  });

  final String financialYear;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final TaxGstSummary gstSummary;
  final TaxRevenueSummary revenueSummary;

  factory TaxAnnualSummary.fromJson(Map<String, dynamic> json) {
    final gstSummary = (json['gstSummary'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final revenueSummary = (json['revenueSummary'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return TaxAnnualSummary(
      financialYear: json['financialYear'] as String? ?? '',
      periodStart: _parseDateTime(json['periodStart']),
      periodEnd: _parseDateTime(json['periodEnd']),
      gstSummary: TaxGstSummary.fromJson(gstSummary),
      revenueSummary: TaxRevenueSummary.fromJson(revenueSummary),
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

  Future<Map<String, int>> bulkRetryPayouts() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/payouts/bulk-retry',
      data: const {},
    );
    final data = response.data ?? const <String, dynamic>{};
    return {
      'attempted': (data['attempted'] as num?)?.toInt() ?? 0,
      'succeeded': (data['succeeded'] as num?)?.toInt() ?? 0,
      'failed': (data['failed'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, int>> bulkRetryRefunds() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/refunds/bulk-retry',
      data: const {},
    );
    final data = response.data ?? const <String, dynamic>{};
    return {
      'attempted': (data['attempted'] as num?)?.toInt() ?? 0,
      'succeeded': (data['succeeded'] as num?)?.toInt() ?? 0,
      'failed': (data['failed'] as num?)?.toInt() ?? 0,
    };
  }

  Future<TaxGstSummary> fetchTaxGstSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/tax-summary/gst',
      queryParameters: {
        'startDate': _formatDate(startDate),
        'endDate': _formatDate(endDate),
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    return TaxGstSummary.fromJson((data['gstSummary'] as Map?)?.cast<String, dynamic>() ?? data);
  }

  Future<TaxRevenueSummary> fetchTaxRevenueSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/tax-summary/revenue',
      queryParameters: {
        'startDate': _formatDate(startDate),
        'endDate': _formatDate(endDate),
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    return TaxRevenueSummary.fromJson((data['revenueSummary'] as Map?)?.cast<String, dynamic>() ?? data);
  }

  Future<TaxAnnualSummary> fetchTaxAnnualSummary(String financialYear) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/tax-summary/annual',
      queryParameters: {
        'financialYear': financialYear,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    return TaxAnnualSummary.fromJson((data['annualSummary'] as Map?)?.cast<String, dynamic>() ?? data);
  }

  /// Returns the full URL to download a CSV of payouts.
  /// The admin panel opens this URL in a new tab via url_launcher.
  String payoutsCsvUrl({String? status}) {
    final base = _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    final query = status != null && status.isNotEmpty && status != 'all'
        ? '?status=$status'
        : '';
    return '$base/api/admin/payouts/export/csv$query';
  }

  String refundsCsvUrl({String? status}) {
    final base = _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    final query = status != null && status.isNotEmpty && status != 'all'
        ? '?status=$status'
        : '';
    return '$base/api/admin/refunds/export/csv$query';
  }

  String taxSummaryCsvUrl({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final base = _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/api/admin/tax-summary/export/csv?startDate=${_formatDate(startDate)}&endDate=${_formatDate(endDate)}';
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

String _formatDate(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
