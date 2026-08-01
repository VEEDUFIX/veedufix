class CatalogTranslation {
  const CatalogTranslation({
    required this.locale,
    required this.name,
    this.description,
    this.shortDescription,
    this.seoTitle,
    this.seoDescription,
  });

  final String locale;
  final String name;
  final String? description;
  final String? shortDescription;
  final String? seoTitle;
  final String? seoDescription;

  factory CatalogTranslation.fromJson(Map<String, dynamic> json) {
    return CatalogTranslation(
      locale: json['locale'] as String? ?? 'en',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      shortDescription: json['shortDescription'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locale': locale,
      'name': name,
      'description': description,
      'shortDescription': shortDescription,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
    };
  }
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.seoTitle,
    this.seoDescription,
    this.sortOrder = 0,
    this.isActive = true,
    this.featured = false,
    this.popular = false,
    this.subcategories = const [],
    this.serviceCount = 0,
    this.translations = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final String? seoTitle;
  final String? seoDescription;
  final int sortOrder;
  final bool isActive;
  final bool featured;
  final bool popular;
  final List<CatalogSubcategory> subcategories;
  final int serviceCount;
  final List<CatalogTranslation> translations;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      featured: json['featured'] as bool? ?? false,
      popular: json['popular'] as bool? ?? false,
      subcategories: _decodeList(json['subcategories'], CatalogSubcategory.fromJson),
      serviceCount: (json['_count'] is Map<String, dynamic>)
          ? ((json['_count'] as Map<String, dynamic>)['services'] as num?)?.toInt() ?? 0
          : (json['serviceCount'] as num?)?.toInt() ?? 0,
      translations: _decodeList(json['translations'], CatalogTranslation.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'iconUrl': iconUrl,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'featured': featured,
      'popular': popular,
      'subcategories': subcategories.map((item) => item.toJson()).toList(growable: false),
      'serviceCount': serviceCount,
      'translations': translations.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class CatalogSubcategory {
  const CatalogSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.seoTitle,
    this.seoDescription,
    this.basePrice = 0,
    this.sortOrder = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.isActive = true,
    this.services = const [],
    this.translations = const [],
  });

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final String? seoTitle;
  final String? seoDescription;
  final double basePrice;
  final int sortOrder;
  final double rating;
  final int reviewCount;
  final bool isActive;
  final List<CatalogService> services;
  final List<CatalogTranslation> translations;

  factory CatalogSubcategory.fromJson(Map<String, dynamic> json) {
    return CatalogSubcategory(
      id: json['id'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
      basePrice: _toDouble(json['basePrice']),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      rating: _toDouble(json['rating']),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      services: _decodeList(json['catalogServices'] ?? json['services'], CatalogService.fromJson),
      translations: _decodeList(json['translations'], CatalogTranslation.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'slug': slug,
      'description': description,
      'iconUrl': iconUrl,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
      'basePrice': basePrice,
      'sortOrder': sortOrder,
      'rating': rating,
      'reviewCount': reviewCount,
      'isActive': isActive,
      'services': services.map((item) => item.toJson()).toList(growable: false),
      'translations': translations.map((item) => item.toJson()).toList(growable: false),
    };
  }

  int get serviceCount => services.length;
}

class CatalogServiceImage {
  const CatalogServiceImage({
    required this.id,
    required this.url,
    this.altText,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  final String id;
  final String url;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;

  factory CatalogServiceImage.fromJson(Map<String, dynamic> json) {
    return CatalogServiceImage(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      altText: json['altText'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'altText': altText,
      'sortOrder': sortOrder,
      'isPrimary': isPrimary,
    };
  }
}

class CatalogServiceRequirement {
  const CatalogServiceRequirement({
    required this.id,
    required this.name,
    required this.slug,
    this.isMandatory = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String slug;
  final bool isMandatory;
  final int sortOrder;

  factory CatalogServiceRequirement.fromJson(Map<String, dynamic> json) {
    return CatalogServiceRequirement(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      isMandatory: json['isMandatory'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'isMandatory': isMandatory,
      'sortOrder': sortOrder,
    };
  }
}

class CatalogPriceRule {
  const CatalogPriceRule({
    required this.id,
    required this.type,
    required this.title,
    required this.price,
    this.cityId,
    this.description,
    this.currency = 'INR',
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.priority = 0,
  });

  final String id;
  final String type;
  final String title;
  final String? cityId;
  final String? description;
  final String currency;
  final double price;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final int priority;

  factory CatalogPriceRule.fromJson(Map<String, dynamic> json) {
    return CatalogPriceRule(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'BASE',
      title: json['title'] as String? ?? '',
      cityId: json['cityId'] as String?,
      description: json['description'] as String?,
      currency: json['currency'] as String? ?? 'INR',
      price: _toDouble(json['price']),
      startsAt: DateTime.tryParse(json['startsAt'] as String? ?? ''),
      endsAt: DateTime.tryParse(json['endsAt'] as String? ?? ''),
      isActive: json['isActive'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'cityId': cityId,
      'description': description,
      'currency': currency,
      'price': price,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'isActive': isActive,
      'priority': priority,
    };
  }
}

class CatalogService {
  const CatalogService({
    required this.id,
    required this.categoryId,
    required this.subcategoryId,
    required this.name,
    required this.slug,
    required this.code,
    required this.startingPrice,
    required this.estimatedDurationMins,
    this.description,
    this.shortDescription,
    this.warrantyDays = 0,
    this.gstApplicable = true,
    this.emergencyAvailable = false,
    this.homeVisit = true,
    this.isActive = true,
    this.featured = false,
    this.popular = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.cancellationPolicy,
    this.seoTitle,
    this.seoDescription,
    this.seoKeywords,
    this.iconUrl,
    this.sortOrder = 0,
    this.category,
    this.subcategory,
    this.translations = const [],
    this.images = const [],
    this.requiredSkills = const [],
    this.requiredTools = const [],
    this.requiredDocuments = const [],
    this.pricingRules = const [],
    this.inclusions = const [],
    this.exclusions = const [],
  });

  final String id;
  final String categoryId;
  final String subcategoryId;
  final String name;
  final String slug;
  final String code;
  final String? description;
  final String? shortDescription;
  final double startingPrice;
  final int estimatedDurationMins;
  final int warrantyDays;
  final bool gstApplicable;
  final bool emergencyAvailable;
  final bool homeVisit;
  final bool isActive;
  final bool featured;
  final bool popular;
  final double rating;
  final int reviewCount;
  final String? cancellationPolicy;
  final String? seoTitle;
  final String? seoDescription;
  final String? seoKeywords;
  final String? iconUrl;
  final int sortOrder;
  final CatalogCategory? category;
  final CatalogSubcategory? subcategory;
  final List<CatalogTranslation> translations;
  final List<CatalogServiceImage> images;
  final List<CatalogServiceRequirement> requiredSkills;
  final List<CatalogServiceRequirement> requiredTools;
  final List<CatalogServiceRequirement> requiredDocuments;
  final List<CatalogPriceRule> pricingRules;
  final List<String> inclusions;
  final List<String> exclusions;

  factory CatalogService.fromJson(Map<String, dynamic> json) {
    return CatalogService(
      id: json['id'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      subcategoryId: json['subcategoryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String?,
      shortDescription: json['shortDescription'] as String?,
      startingPrice: _toDouble(json['startingPrice']),
      estimatedDurationMins: (json['estimatedDurationMins'] as num?)?.toInt() ?? 0,
      warrantyDays: (json['warrantyDays'] as num?)?.toInt() ?? 0,
      gstApplicable: json['gstApplicable'] as bool? ?? true,
      emergencyAvailable: json['emergencyAvailable'] as bool? ?? false,
      homeVisit: json['homeVisit'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? true,
      featured: json['featured'] as bool? ?? false,
      popular: json['popular'] as bool? ?? false,
      rating: _toDouble(json['rating']),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      cancellationPolicy: json['cancellationPolicy'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
      seoKeywords: json['seoKeywords'] as String?,
      iconUrl: json['iconUrl'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      category: json['category'] is Map<String, dynamic>
          ? CatalogCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      subcategory: json['subcategory'] is Map<String, dynamic>
          ? CatalogSubcategory.fromJson(json['subcategory'] as Map<String, dynamic>)
          : null,
      translations: _decodeList(json['translations'], CatalogTranslation.fromJson),
      images: _decodeList(json['images'], CatalogServiceImage.fromJson),
      requiredSkills: _decodeList(json['requiredSkills'], CatalogServiceRequirement.fromJson),
      requiredTools: _decodeList(json['requiredTools'], CatalogServiceRequirement.fromJson),
      requiredDocuments: _decodeList(json['requiredDocuments'], CatalogServiceRequirement.fromJson),
      pricingRules: _decodeList(json['pricingRules'], CatalogPriceRule.fromJson),
      inclusions: (json['inclusions'] as List<dynamic>?)?.cast<String>() ?? const [],
      exclusions: (json['exclusions'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
      'name': name,
      'slug': slug,
      'code': code,
      'description': description,
      'shortDescription': shortDescription,
      'startingPrice': startingPrice,
      'estimatedDurationMins': estimatedDurationMins,
      'warrantyDays': warrantyDays,
      'gstApplicable': gstApplicable,
      'emergencyAvailable': emergencyAvailable,
      'homeVisit': homeVisit,
      'isActive': isActive,
      'featured': featured,
      'popular': popular,
      'rating': rating,
      'reviewCount': reviewCount,
      'cancellationPolicy': cancellationPolicy,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
      'seoKeywords': seoKeywords,
      'iconUrl': iconUrl,
      'sortOrder': sortOrder,
      'category': category?.toJson(),
      'subcategory': subcategory?.toJson(),
      'translations': translations.map((item) => item.toJson()).toList(growable: false),
      'images': images.map((item) => item.toJson()).toList(growable: false),
      'requiredSkills': requiredSkills.map((item) => item.toJson()).toList(growable: false),
      'requiredTools': requiredTools.map((item) => item.toJson()).toList(growable: false),
      'requiredDocuments': requiredDocuments.map((item) => item.toJson()).toList(growable: false),
      'pricingRules': pricingRules.map((item) => item.toJson()).toList(growable: false),
      'inclusions': inclusions,
      'exclusions': exclusions,
    };
  }

  String get hierarchyLabel {
    final categoryName = category?.name.trim();
    final subcategoryName = subcategory?.name.trim();
    final parts = <String>[
      if (categoryName != null && categoryName.isNotEmpty) categoryName,
      if (subcategoryName != null && subcategoryName.isNotEmpty) subcategoryName,
    ];
    return parts.isEmpty ? '' : parts.join(' · ');
  }
}

class CatalogSearchSuggestion {
  const CatalogSearchSuggestion({
    required this.label,
    required this.kind,
    this.slug,
    this.categorySlug,
    this.subcategorySlug,
  });

  final String label;
  final String kind;
  final String? slug;
  final String? categorySlug;
  final String? subcategorySlug;

  factory CatalogSearchSuggestion.fromJson(Map<String, dynamic> json) {
    return CatalogSearchSuggestion(
      label: json['label'] as String? ?? '',
      kind: json['kind'] as String? ?? 'SERVICE',
      slug: json['slug'] as String?,
      categorySlug: json['categorySlug'] as String?,
      subcategorySlug: json['subcategorySlug'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'kind': kind,
      'slug': slug,
      'categorySlug': categorySlug,
      'subcategorySlug': subcategorySlug,
    };
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

List<T> _decodeList<T>(dynamic value, T Function(Map<String, dynamic>) builder) {
  if (value is! List) {
    return <T>[];
  }

  return value
      .whereType<Map<String, dynamic>>()
      .map(builder)
      .toList(growable: false);
}
