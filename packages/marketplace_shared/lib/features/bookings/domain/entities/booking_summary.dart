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
    this.addressLabel,
    this.cityName,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationQuery,
  });

  final String bookingId;
  final String code;
  final String status;
  final String customerName;
  final String? customerAvatarUrl;
  final BookingSummaryWorker? worker;
  final String? addressLabel;
  final String? cityName;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationQuery;

  factory BookingSummary.fromJson(Map<String, dynamic> json) {
    final customerMap = json['customer'] as Map<String, dynamic>?;
    final workerMap = json['worker'] as Map<String, dynamic>?;
    final addressMap = _asMap([
      json['address'],
      json['location'],
      json['customerAddress'],
      customerMap?['address'],
      customerMap?['location'],
    ]);
    return BookingSummary(
      bookingId: json['bookingId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      customerName: customerMap?['name'] as String? ?? 'Customer',
      customerAvatarUrl: customerMap?['avatarUrl'] as String?,
      worker: workerMap != null
          ? BookingSummaryWorker.fromJson(workerMap)
          : null,
      addressLabel: _firstString([
        json['addressLabel'],
        json['locationLabel'],
        addressMap['label'],
        addressMap['addressLabel'],
      ]),
      cityName: _firstString([
        json['cityName'],
        addressMap['city'],
        addressMap['cityName'],
      ]),
      destinationLatitude: _doubleValue([
        json['destinationLatitude'],
        json['addressLatitude'],
        json['lat'],
        addressMap['lat'],
        addressMap['latitude'],
        customerMap?['lat'],
        customerMap?['latitude'],
      ]),
      destinationLongitude: _doubleValue([
        json['destinationLongitude'],
        json['addressLongitude'],
        json['lng'],
        json['lon'],
        addressMap['lng'],
        addressMap['lon'],
        addressMap['longitude'],
        customerMap?['lng'],
        customerMap?['lon'],
        customerMap?['longitude'],
      ]),
      destinationQuery: _firstString([
        json['destinationQuery'],
        addressMap['displayAddress'],
        addressMap['fullAddress'],
        addressMap['formattedAddress'],
      ]),
    );
  }
}

Map<String, dynamic> _asMap(Iterable<dynamic> candidates) {
  for (final candidate in candidates) {
    if (candidate is Map<String, dynamic>) {
      return candidate;
    }
    if (candidate is Map) {
      return candidate.cast<String, dynamic>();
    }
  }
  return <String, dynamic>{};
}

String? _firstString(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
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
