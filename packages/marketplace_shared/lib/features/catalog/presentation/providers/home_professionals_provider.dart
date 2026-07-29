import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class HomeProfessional {
  const HomeProfessional({
    required this.name,
    required this.role,
    required this.experience,
    required this.rating,
    required this.distance,
    required this.price,
    required this.verified,
    required this.accent,
  });

  final String name;
  final String role;
  final String experience;
  final double rating;
  final String distance;
  final String price;
  final bool verified;
  final Color accent;

  factory HomeProfessional.fromJson(Map<String, dynamic> json) {
    return HomeProfessional(
      name: json['name'] as String? ?? 'Professional',
      role: json['role'] as String? ?? 'Expert',
      experience: json['experience'] as String? ?? 'New',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      distance: json['distance'] as String? ?? 'Nearby',
      price: json['price'] as String? ?? 'Get quote',
      verified: json['verified'] as bool? ?? false,
      accent: Color(json['accent'] as int? ?? 0xFF10B981),
    );
  }
}

final homeProfessionalsProvider = FutureProvider.autoDispose<List<HomeProfessional>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/catalog/professionals');
  final items = response['professionals'] as List<dynamic>? ?? [];
  return items
      .whereType<Map<String, dynamic>>()
      .map(HomeProfessional.fromJson)
      .toList(growable: false);
});
