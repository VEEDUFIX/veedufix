class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.imageUrl,
    required this.destinationType,
    required this.destinationValue,
    required this.sortOrder,
  });

  final String id;
  final String imageUrl;
  final String destinationType;
  final String destinationValue;
  final int sortOrder;

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
    id: json['id'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    destinationType: json['destinationType'] as String? ?? '',
    destinationValue: json['destinationValue'] as String? ?? '',
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  );
}
