class WorkerPublicProfileSkill {
  const WorkerPublicProfileSkill({
    required this.id,
    required this.categoryName,
    required this.categorySlug,
  });

  final String id;
  final String categoryName;
  final String categorySlug;

  factory WorkerPublicProfileSkill.fromJson(Map<String, dynamic> json) {
    return WorkerPublicProfileSkill(
      id: json['id'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      categorySlug: json['categorySlug'] as String? ?? '',
    );
  }
}

class WorkerPublicProfilePhoto {
  const WorkerPublicProfilePhoto({
    required this.id,
    required this.url,
    this.caption,
  });

  final String id;
  final String url;
  final String? caption;

  factory WorkerPublicProfilePhoto.fromJson(Map<String, dynamic> json) {
    return WorkerPublicProfilePhoto(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      caption: json['caption'] as String?,
    );
  }
}

class WorkerPublicProfileReview {
  const WorkerPublicProfileReview({
    required this.id,
    required this.rating,
    this.comment,
    required this.customerName,
    this.customerAvatarUrl,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String? comment;
  final String customerName;
  final String? customerAvatarUrl;
  final DateTime createdAt;

  factory WorkerPublicProfileReview.fromJson(Map<String, dynamic> json) {
    return WorkerPublicProfileReview(
      id: json['id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      customerName: json['customerName'] as String? ?? 'Customer',
      customerAvatarUrl: json['customerAvatarUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class WorkerPublicProfile {
  const WorkerPublicProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    required this.averageRating,
    required this.completedJobsCount,
    required this.experienceYears,
    required this.isAvailable,
    required this.verificationStatus,
    this.skills = const [],
    this.portfolioPhotos = const [],
    this.reviews = const [],
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final double averageRating;
  final int completedJobsCount;
  final int experienceYears;
  final bool isAvailable;
  final String verificationStatus;
  final List<WorkerPublicProfileSkill> skills;
  final List<WorkerPublicProfilePhoto> portfolioPhotos;
  final List<WorkerPublicProfileReview> reviews;

  factory WorkerPublicProfile.fromJson(Map<String, dynamic> json) {
    List<T> decodeList<T>(dynamic value, T Function(Map<String, dynamic>) builder) {
      if (value is! List) return <T>[];
      return value.whereType<Map<String, dynamic>>().map(builder).toList(growable: false);
    }

    return WorkerPublicProfile(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Professional',
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      completedJobsCount: (json['completedJobsCount'] as num?)?.toInt() ?? 0,
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? false,
      verificationStatus: json['verificationStatus'] as String? ?? 'PENDING',
      skills: decodeList(json['skills'], WorkerPublicProfileSkill.fromJson),
      portfolioPhotos: decodeList(json['portfolioPhotos'], WorkerPublicProfilePhoto.fromJson),
      reviews: decodeList(json['reviews'], WorkerPublicProfileReview.fromJson),
    );
  }
}
