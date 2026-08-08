class WorkerEarningsChartPoint {
  const WorkerEarningsChartPoint({
    required this.date,
    required this.amount,
  });

  final DateTime date;
  final double amount;

  factory WorkerEarningsChartPoint.fromJson(Map<String, dynamic> json) {
    return WorkerEarningsChartPoint(
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WorkerEarningsSummary {
  const WorkerEarningsSummary({
    required this.todayTotal,
    required this.weeklyTotal,
    required this.monthlyTotal,
    required this.chartData,
  });

  final double todayTotal;
  final double weeklyTotal;
  final double monthlyTotal;
  final List<WorkerEarningsChartPoint> chartData;

  factory WorkerEarningsSummary.fromJson(Map<String, dynamic> json) {
    final chartItems = json['chartData'];
    return WorkerEarningsSummary(
      todayTotal: (json['todayTotal'] as num?)?.toDouble() ?? 0,
      weeklyTotal: (json['weeklyTotal'] as num?)?.toDouble() ?? 0,
      monthlyTotal: (json['monthlyTotal'] as num?)?.toDouble() ?? 0,
      chartData: chartItems is List
          ? chartItems
              .whereType<Map<String, dynamic>>()
              .map(WorkerEarningsChartPoint.fromJson)
              .toList(growable: false)
          : const <WorkerEarningsChartPoint>[],
    );
  }
}

class WorkerEarningsTransaction {
  const WorkerEarningsTransaction({
    required this.bookingId,
    required this.bookingCode,
    required this.serviceName,
    required this.amount,
    required this.commissionAmount,
    required this.status,
    required this.date,
  });

  final String bookingId;
  final String? bookingCode;
  final String serviceName;
  final double amount;
  final double commissionAmount;
  final String status;
  final DateTime date;

  factory WorkerEarningsTransaction.fromJson(Map<String, dynamic> json) {
    return WorkerEarningsTransaction(
      bookingId: json['bookingId'] as String? ?? '',
      bookingCode: json['bookingCode'] as String?,
      serviceName: json['serviceName'] as String? ?? 'Service booking',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class WorkerEarningsTransactionPage {
  const WorkerEarningsTransactionPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<WorkerEarningsTransaction> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class WorkerEarningsPageData {
  const WorkerEarningsPageData({
    required this.summary,
    required this.transactions,
  });

  final WorkerEarningsSummary summary;
  final List<WorkerEarningsTransaction> transactions;
}
