class BookingSummaryWorker {
  const BookingSummaryWorker({
    required this.id,
    required this.name,
    required this.rating,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final double rating;
  final String? avatarUrl;

  factory BookingSummaryWorker.fromJson(Map<String, dynamic> json) =>
      BookingSummaryWorker(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Professional',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class BookingSummary {
  const BookingSummary({
    required this.bookingId,
    required this.code,
    required this.status,
    required this.customerName,
    this.worker,
    this.customerAvatarUrl,
  });

  final String bookingId;
  final String code;
  final String status;
  final String customerName;
  final String? customerAvatarUrl;
  final BookingSummaryWorker? worker;

  factory BookingSummary.fromJson(Map<String, dynamic> json) {
    final customerMap = json['customer'] as Map<String, dynamic>?;
    final workerMap = json['worker'] as Map<String, dynamic>?;
    return BookingSummary(
      bookingId: json['bookingId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      customerName: customerMap?['name'] as String? ?? 'Customer',
      customerAvatarUrl: customerMap?['avatarUrl'] as String?,
      worker: workerMap != null
          ? BookingSummaryWorker.fromJson(workerMap)
          : null,
    );
  }
}
