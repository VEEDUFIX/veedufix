class CouponModel {
  const CouponModel({
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.minOrderAmount,
    this.expiresAt,
  });

  final String code;
  final String title;
  final String description;
  final String discountType; // PERCENTAGE or FLAT
  final double discountValue;
  final double? maxDiscountAmount;
  final double? minOrderAmount;
  final DateTime? expiresAt;

  factory CouponModel.fromJson(Map<String, dynamic> json) => CouponModel(
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? json['code'] as String? ?? '',
        description: json['description'] as String? ?? '',
        discountType: json['discountType'] as String? ?? 'FLAT',
        discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
        maxDiscountAmount: (json['maxDiscountAmount'] as num?)?.toDouble(),
        minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble(),
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
      );

  String get expiryLabel {
    if (expiresAt == null) return 'No expiry';
    final d = expiresAt!;
    return 'Valid till ${d.day} ${_months[d.month - 1]}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get discountLabel {
    if (discountType == 'PERCENTAGE') return '${discountValue.toInt()}% off';
    return '\u20b9${discountValue.toInt()} off';
  }
}
