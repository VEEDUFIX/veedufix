import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WorkerReviewQueueResponse {
  const WorkerReviewQueueResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<WorkerReviewProfile> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
}

class WorkerReviewProfile {
  const WorkerReviewProfile({
    required this.id,
    required this.userId,
    required this.onboardingStatus,
    required this.fullName,
    required this.dateOfBirth,
    required this.addressLine1,
    required this.city,
    required this.pincode,
    required this.aadhaarNumber,
    required this.hasAadhaarDoc,
    required this.upiId,
    required this.bankAccountNumber,
    required this.bankIfsc,
    required this.rejectionReason,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.user,
    required this.skills,
  });

  final String id;
  final String userId;
  final String onboardingStatus;
  final String? fullName;
  final DateTime? dateOfBirth;
  final String? addressLine1;
  final String? city;
  final String? pincode;
  final String? aadhaarNumber;
  /// True when the server has an Aadhaar document on file.
  /// The raw URL is never sent to the client; use [WorkerReviewApi.fetchAadhaarDocUrl]
  /// to obtain a short-lived signed URL for viewing.
  final bool hasAadhaarDoc;
  final String? upiId;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final WorkerReviewUserSummary? user;
  final List<WorkerReviewSkill> skills;

  factory WorkerReviewProfile.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : const <String, dynamic>{};
    return WorkerReviewProfile(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? userJson['id'] as String? ?? '',
      onboardingStatus: json['onboardingStatus'] as String? ?? 'pending_documents',
      fullName: json['fullName'] as String?,
      dateOfBirth: _parseDateTime(json['dateOfBirth']),
      addressLine1: json['addressLine1'] as String?,
      city: json['city'] as String?,
      pincode: json['pincode'] as String?,
      aadhaarNumber: json['aadhaarNumber'] as String?,
      // Backward-compat: fall back to old aadhaarDocUrl field if the new
      // hasAadhaarDoc field is not present (older backend response).
      hasAadhaarDoc: json['hasAadhaarDoc'] as bool? ??
          (json['aadhaarDocUrl'] as String?)?.isNotEmpty == true,
      upiId: json['upiId'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfsc: json['bankIfsc'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      submittedAt: _parseDateTime(json['submittedAt']),
      reviewedAt: _parseDateTime(json['reviewedAt']),
      reviewedBy: json['reviewedBy'] as String?,
      user: userJson.isEmpty ? null : WorkerReviewUserSummary.fromJson(userJson),
      skills: (json['skills'] as List?)?.whereType<Map<String, dynamic>>().map(WorkerReviewSkill.fromJson).toList() ?? const [],
    );
  }

  String get displayName {
    return fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : user?.name?.trim().isNotEmpty == true
            ? user!.name!.trim()
            : 'Unknown worker';
  }

  String get cityLabel {
    return city?.trim().isNotEmpty == true ? city!.trim() : 'Not specified';
  }

  String get submittedLabel {
    final timestamp = submittedAt ?? reviewedAt;
    if (timestamp == null) {
      return 'Pending submission date';
    }
    return DateFormat.yMMMd().format(timestamp);
  }

  String get maskedAadhaar {
    final value = aadhaarNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (value.isEmpty) {
      return 'Not provided';
    }
    final last4 = value.length >= 4 ? value.substring(value.length - 4) : value.padLeft(4, '0');
    return 'XXXX-XXXX-$last4';
  }

  List<String> get requestedCategoryNames {
    final names = skills
        .map((skill) => skill.category?.name?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return names;
  }
}

class WorkerReviewUserSummary {
  const WorkerReviewUserSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.avatarUrl,
  });

  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? role;
  final String? avatarUrl;

  factory WorkerReviewUserSummary.fromJson(Map<String, dynamic> json) {
    return WorkerReviewUserSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class WorkerReviewSkill {
  const WorkerReviewSkill({
    required this.id,
    required this.categoryId,
    required this.hasCertificationDoc,
    required this.verifiedByAdmin,
    required this.yearsExperience,
    required this.isPrimary,
    required this.category,
  });

  final String id;
  final String categoryId;
  /// True when the server has a certification document on file for this skill.
  /// Use [WorkerReviewApi.fetchCertDocUrl] to obtain a short-lived signed URL.
  final bool hasCertificationDoc;
  final bool verifiedByAdmin;
  final num? yearsExperience;
  final bool isPrimary;
  final WorkerReviewSkillCategory? category;

  factory WorkerReviewSkill.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'] is Map<String, dynamic>
        ? json['category'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return WorkerReviewSkill(
      id: json['id'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? categoryJson['id'] as String? ?? '',
      // Backward-compat: fall back to old certificationDocUrl field.
      hasCertificationDoc: json['hasCertificationDoc'] as bool? ??
          (json['certificationDocUrl'] as String?)?.isNotEmpty == true,
      verifiedByAdmin: json['verifiedByAdmin'] as bool? ?? false,
      yearsExperience: json['yearsExperience'] as num?,
      isPrimary: json['isPrimary'] as bool? ?? false,
      category: categoryJson.isEmpty ? null : WorkerReviewSkillCategory.fromJson(categoryJson),
    );
  }
}

class WorkerReviewSkillCategory {
  const WorkerReviewSkillCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.iconUrl,
  });

  final String id;
  final String? name;
  final String? slug;
  final String? description;
  final String? iconUrl;

  factory WorkerReviewSkillCategory.fromJson(Map<String, dynamic> json) {
    return WorkerReviewSkillCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
    );
  }
}

class WorkerReviewApi {
  WorkerReviewApi(this._dio);

  final Dio _dio;

  Future<WorkerReviewQueueResponse> fetchPending({
    int page = 1,
    int limit = 20,
    String? city,
    String? categoryId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/worker-review/pending',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (categoryId != null && categoryId.trim().isNotEmpty) 'categoryId': categoryId.trim(),
      },
    );
    final payload = response.data ?? <String, dynamic>{};
    final items = (payload['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WorkerReviewProfile.fromJson)
        .toList(growable: false);
    return WorkerReviewQueueResponse(
      items: items,
      page: (payload['page'] as num?)?.toInt() ?? page,
      limit: (payload['limit'] as num?)?.toInt() ?? limit,
      total: (payload['total'] as num?)?.toInt() ?? items.length,
      totalPages: (payload['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<List<CatalogCategory>> fetchCategories() async {
    final response = await _dio.get<Map<String, dynamic>>('/catalog');
    final categories = response.data?['categories'];
    if (categories is! List) {
      return const <CatalogCategory>[];
    }
    return categories
        .whereType<Map<String, dynamic>>()
        .map(CatalogCategory.fromJson)
        .toList(growable: false);
  }

  Future<WorkerReviewProfile> approve(String profileId) async {
    final response = await _dio.post<Map<String, dynamic>>('/admin/worker-review/$profileId/approve');
    return _parseProfile(response.data);
  }

  Future<WorkerReviewProfile> reject(String profileId, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/worker-review/$profileId/reject',
      data: {'reason': reason},
    );
    return _parseProfile(response.data);
  }

  Future<WorkerReviewProfile> suspend(String profileId, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/worker-review/$profileId/suspend',
      data: {'reason': reason},
    );
    return _parseProfile(response.data);
  }

  WorkerReviewProfile _parseProfile(Map<String, dynamic>? payload) {
    final profile = payload?['profile'];
    if (profile is Map<String, dynamic>) {
      return WorkerReviewProfile.fromJson(profile);
    }
    throw StateError('Worker review response was malformed.');
  }

  /// Requests a short-lived (5-minute) signed Cloudinary URL for a worker's
  /// Aadhaar document.  Requires ADMIN auth (handled by the Dio interceptor).
  Future<String> fetchAadhaarDocUrl(String profileId) async {
    final response = await _dio
        .get<Map<String, dynamic>>('/admin/worker-review/$profileId/documents/aadhaar');
    final url = response.data?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Server returned no URL for Aadhaar document.');
    }
    return url;
  }

  /// Requests a short-lived (5-minute) signed Cloudinary URL for a skill's
  /// certification document.  Requires ADMIN auth.
  Future<String> fetchCertDocUrl(String profileId, String skillId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/worker-review/$profileId/documents/skills/$skillId/certification',
    );
    final url = response.data?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Server returned no URL for certification document.');
    }
    return url;
  }
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

String? _shortDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

extension WorkerReviewProfileFormatting on WorkerReviewProfile {
  String get submittedShortDate => _shortDate(submittedAt) ?? _shortDate(reviewedAt) ?? 'Pending';
}
