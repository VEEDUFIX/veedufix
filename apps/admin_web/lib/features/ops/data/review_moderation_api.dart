import 'package:dio/dio.dart';

class ReviewModerationItem {
  const ReviewModerationItem({
    required this.reportId,
    required this.reviewId,
    required this.reason,
    required this.reportedAt,
    required this.rating,
    required this.comment,
    required this.workerResponse,
    required this.reviewStatus,
    required this.reportStatus,
    required this.reviewerName,
    required this.reporterName,
    required this.workerName,
    required this.bookingCode,
  });

  final String reportId;
  final String reviewId;
  final String reason;
  final DateTime reportedAt;
  final int rating;
  final String? comment;
  final String? workerResponse;
  final String reviewStatus;
  final String reportStatus;
  final String reviewerName;
  final String reporterName;
  final String workerName;
  final String bookingCode;

  factory ReviewModerationItem.fromJson(Map<String, dynamic> json) {
    final review = (json['review'] as Map?)?.cast<String, dynamic>() ?? {};
    final reviewer = (review['reviewer'] as Map?)?.cast<String, dynamic>() ?? {};
    final reporter = (json['reporter'] as Map?)?.cast<String, dynamic>() ?? {};
    final worker = (review['worker'] as Map?)?.cast<String, dynamic>() ?? {};
    final booking = (review['booking'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = worker['fullName'] as String? ?? worker['displayName'] as String?;
    return ReviewModerationItem(
      reportId: json['id'] as String? ?? '',
      reviewId: review['id'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      reportedAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      rating: (review['rating'] as num?)?.toInt() ?? 0,
      comment: review['comment'] as String?,
      workerResponse: review['workerResponse'] as String?,
      reviewStatus: review['moderationStatus'] as String? ?? 'published',
      reportStatus: json['status'] as String? ?? 'open',
      reviewerName: reviewer['name'] as String? ?? 'Customer',
      reporterName: reporter['name'] as String? ?? 'Customer',
      workerName: name?.trim().isNotEmpty == true ? name!.trim() : 'Professional',
      bookingCode: booking['code'] as String? ?? '',
    );
  }
}

class ReviewModerationResponse {
  const ReviewModerationResponse({required this.items, required this.total});

  final List<ReviewModerationItem> items;
  final int total;

  factory ReviewModerationResponse.fromJson(Map<String, dynamic> json) =>
      ReviewModerationResponse(
        items: (json['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ReviewModerationItem.fromJson)
            .toList(growable: false),
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

class ReviewModerationApi {
  ReviewModerationApi(this._dio);

  final Dio _dio;

  Future<ReviewModerationResponse> fetchReports({int page = 1, int pageSize = 50}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reviews/admin/reports',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return ReviewModerationResponse.fromJson(response.data ?? const {});
  }

  Future<void> setVisibility(String reviewId, {required bool visible}) async {
    await _dio.patch<Map<String, dynamic>>(
      '/reviews/admin/${Uri.encodeComponent(reviewId)}/moderation',
      data: {'status': visible ? 'published' : 'hidden'},
    );
  }

  Future<void> dismissReport(String reportId) async {
    await _dio.patch<Map<String, dynamic>>(
      '/reviews/admin/reports/${Uri.encodeComponent(reportId)}/dismiss',
    );
  }
}
