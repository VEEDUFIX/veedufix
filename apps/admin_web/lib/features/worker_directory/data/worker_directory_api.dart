import 'package:dio/dio.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WorkerDirectoryQueueResponse {
  const WorkerDirectoryQueueResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<WorkerDirectoryProfile> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory WorkerDirectoryQueueResponse.fromJson(Map<String, dynamic> json) {
    return WorkerDirectoryQueueResponse(
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkerDirectoryProfile.fromJson)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class WorkerDirectoryProfile {
  const WorkerDirectoryProfile({
    required this.id,
    required this.userId,
    required this.onboardingStatus,
    required this.fullName,
    required this.city,
    required this.ratingAvg,
    required this.jobsCompletedCount,
    required this.noShowCount,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.rejectionReason,
    required this.userName,
    required this.avatarUrl,
    required this.skills,
  });

  final String id;
  final String userId;
  final String onboardingStatus;
  final String? fullName;
  final String? city;
  final double ratingAvg;
  final int jobsCompletedCount;
  final int noShowCount;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final String? userName;
  final String? avatarUrl;
  final List<String> skills;

  factory WorkerDirectoryProfile.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final cityRelation =
        (json['cityRelation'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final skillItems = (json['skills'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return WorkerDirectoryProfile(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? user['id'] as String? ?? '',
      onboardingStatus:
          json['onboardingStatus'] as String? ?? 'pending_documents',
      fullName: json['fullName'] as String?,
      city: (json['city'] as String?)?.trim().isNotEmpty == true
          ? (json['city'] as String).trim()
          : (cityRelation['name'] as String?)?.trim(),
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      jobsCompletedCount: (json['jobsCompletedCount'] as num?)?.toInt() ?? 0,
      noShowCount: (json['noShowCount'] as num?)?.toInt() ?? 0,
      reviewedAt: _parseDateTime(json['reviewedAt']),
      reviewedBy: json['reviewedBy'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      userName: user['name'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      skills: skillItems
          .map((skill) {
            final category =
                (skill['category'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{};
            final name = category['name'] as String?;
            return name?.trim();
          })
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList(growable: false),
    );
  }

  String get displayName {
    if (fullName?.trim().isNotEmpty == true) {
      return fullName!.trim();
    }
    if (userName?.trim().isNotEmpty == true) {
      return userName!.trim();
    }
    return 'Unknown worker';
  }

  String get cityLabel =>
      city?.trim().isNotEmpty == true ? city!.trim() : 'Not specified';

  List<String> get requestedCategoryNames => skills;
}

class WorkerDirectoryRating {
  const WorkerDirectoryRating({
    required this.id,
    required this.bookingCode,
    required this.customerName,
    required this.reviewerName,
    required this.reviewerAvatarUrl,
    required this.rating,
    required this.comment,
    required this.mediaUrls,
    required this.createdAt,
  });

  final String id;
  final String bookingCode;
  final String customerName;
  final String reviewerName;
  final String? reviewerAvatarUrl;
  final int rating;
  final String? comment;
  final List<String> mediaUrls;
  final DateTime createdAt;

  factory WorkerDirectoryRating.fromJson(Map<String, dynamic> json) {
    return WorkerDirectoryRating(
      id: json['id'] as String? ?? '',
      bookingCode: json['bookingCode'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Customer',
      reviewerName: json['reviewerName'] as String? ?? 'Admin',
      reviewerAvatarUrl: json['reviewerAvatarUrl'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      mediaUrls: (json['mediaUrls'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class WorkerDirectoryStatusEvent {
  const WorkerDirectoryStatusEvent({
    required this.type,
    required this.status,
    required this.note,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.verificationStatus,
  });

  final String type;
  final String status;
  final String? note;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? verificationStatus;

  factory WorkerDirectoryStatusEvent.fromJson(Map<String, dynamic> json) {
    return WorkerDirectoryStatusEvent(
      type: json['type'] as String? ?? 'status',
      status: json['status'] as String? ?? 'unknown',
      note: json['note'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: _parseDateTime(json['reviewedAt']),
      verificationStatus: json['verificationStatus'] as String?,
    );
  }
}

class WorkerDirectoryHistoryResponse {
  const WorkerDirectoryHistoryResponse({
    required this.worker,
    required this.noShowCount,
    required this.ratings,
    required this.statusEvents,
  });

  final WorkerDirectoryProfile worker;
  final int noShowCount;
  final List<WorkerDirectoryRating> ratings;
  final List<WorkerDirectoryStatusEvent> statusEvents;

  factory WorkerDirectoryHistoryResponse.fromJson(Map<String, dynamic> json) {
    return WorkerDirectoryHistoryResponse(
      worker: WorkerDirectoryProfile.fromJson(
          (json['worker'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{}),
      noShowCount: (json['noShowCount'] as num?)?.toInt() ?? 0,
      ratings: (json['ratings'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkerDirectoryRating.fromJson)
          .toList(growable: false),
      statusEvents: (json['statusEvents'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkerDirectoryStatusEvent.fromJson)
          .toList(growable: false),
    );
  }
}

class WorkerDirectoryApi {
  WorkerDirectoryApi(this._dio);

  final Dio _dio;

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

  Future<WorkerDirectoryQueueResponse> fetchWorkers({
    int page = 1,
    int limit = 20,
    String? city,
    String? categoryId,
    String? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/workers',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (categoryId != null && categoryId.trim().isNotEmpty)
          'categoryId': categoryId.trim(),
        if (status != null && status.trim().isNotEmpty && status != 'all')
          'status': status.trim(),
      },
    );

    return WorkerDirectoryQueueResponse.fromJson(
        response.data ?? const <String, dynamic>{});
  }

  Future<WorkerDirectoryHistoryResponse> fetchHistory(String profileId) async {
    final response = await _dio
        .get<Map<String, dynamic>>('/admin/workers/$profileId/history');
    return WorkerDirectoryHistoryResponse.fromJson(
        response.data ?? const <String, dynamic>{});
  }

  Future<WorkerDirectoryProfile> reinstate(
      String profileId, String note) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/worker-review/$profileId/reinstate',
      data: {'note': note},
    );
    return _parseProfile(response.data);
  }

  Future<WorkerDirectoryProfile> suspend(
      String profileId, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/worker-review/$profileId/suspend',
      data: {'reason': reason},
    );
    return _parseProfile(response.data);
  }

  WorkerDirectoryProfile _parseProfile(Map<String, dynamic>? payload) {
    final profile = payload?['profile'];
    if (profile is Map<String, dynamic>) {
      return WorkerDirectoryProfile.fromJson(profile);
    }
    throw StateError('Worker directory response was malformed.');
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
