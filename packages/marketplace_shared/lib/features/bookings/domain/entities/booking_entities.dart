class BookingWorker {
  const BookingWorker({required this.id, required this.name, required this.rating, this.avatarUrl});
  final String id;
  final String name;
  final double rating;
  final String? avatarUrl;

  factory BookingWorker.fromJson(Map<String, dynamic> json) => BookingWorker(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Professional',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.code,
    required this.status,
    required this.scheduledAt,
    required this.totalAmount,
    required this.serviceName,
    this.serviceIcon,
    this.serviceSlug,
    this.addressLabel,
    this.cityName,
    this.worker,
    this.customQuoteStatus,
    this.customQuoteAmount,
    this.customQuoteNotes,
    this.customQuoteItemized,
  });

  final String id;
  final String code;
  final String status;
  final DateTime scheduledAt;
  final double totalAmount;
  final String serviceName;
  final String? serviceIcon;
  final String? serviceSlug;
  final String? addressLabel;
  final String? cityName;
  final BookingWorker? worker;
  final String? customQuoteStatus;
  final double? customQuoteAmount;
  final String? customQuoteNotes;
  final List<dynamic>? customQuoteItemized;

  factory CustomerBooking.fromJson(Map<String, dynamic> json) => CustomerBooking(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ?? DateTime.now(),
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        serviceName: json['serviceName'] as String? ?? 'Service',
        serviceIcon: json['serviceIcon'] as String?,
        serviceSlug: json['serviceSlug'] as String?,
        addressLabel: json['addressLabel'] as String?,
        cityName: json['cityName'] as String?,
        worker: json['worker'] != null
            ? BookingWorker.fromJson(json['worker'] as Map<String, dynamic>)
            : null,
        customQuoteStatus: json['customQuoteStatus'] as String?,
        customQuoteAmount: (json['customQuoteAmount'] as num?)?.toDouble(),
        customQuoteNotes: json['customQuoteNotes'] as String?,
        customQuoteItemized: json['customQuoteItemized'] as List<dynamic>?,
      );
}
