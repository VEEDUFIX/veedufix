class RebookOptions {
  const RebookOptions({
    required this.sourceBookingId,
    required this.sourceBookingCode,
    required this.canRebook,
    required this.items,
    this.reason,
    this.preferredAddressId,
    this.addressMatched = false,
    this.previouslyQuoted = false,
  });

  final String sourceBookingId;
  final String sourceBookingCode;
  final bool canRebook;
  final String? reason;
  final String? preferredAddressId;
  final bool addressMatched;
  final bool previouslyQuoted;
  final List<RebookOptionItem> items;

  factory RebookOptions.fromJson(Map<String, dynamic> json) => RebookOptions(
    sourceBookingId: json['sourceBookingId'] as String? ?? '',
    sourceBookingCode: json['sourceBookingCode'] as String? ?? '',
    canRebook: json['canRebook'] as bool? ?? false,
    reason: json['reason'] as String?,
    preferredAddressId: json['preferredAddressId'] as String?,
    addressMatched: json['addressMatched'] as bool? ?? false,
    previouslyQuoted: json['previouslyQuoted'] as bool? ?? false,
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (value) => RebookOptionItem.fromJson(value.cast<String, dynamic>()),
        )
        .toList(growable: false),
  );
}

class RebookOptionItem {
  const RebookOptionItem({
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
    required this.addonIds,
    this.serviceSlug,
    this.variantId,
    this.serviceCurrentlyBookable = false,
  });

  final String serviceId;
  final String serviceName;
  final String? serviceSlug;
  final int quantity;
  final String? variantId;
  final List<String> addonIds;
  final bool serviceCurrentlyBookable;

  factory RebookOptionItem.fromJson(Map<String, dynamic> json) =>
      RebookOptionItem(
        serviceId: json['serviceId'] as String? ?? '',
        serviceName: json['serviceName'] as String? ?? 'Previous service',
        serviceSlug: json['serviceSlug'] as String?,
        quantity: ((json['quantity'] as num?)?.toInt() ?? 1).clamp(1, 20),
        variantId: json['variantId'] as String?,
        addonIds: (json['addonIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        serviceCurrentlyBookable: json['serviceCurrentlyBookable'] == true,
      );
}
