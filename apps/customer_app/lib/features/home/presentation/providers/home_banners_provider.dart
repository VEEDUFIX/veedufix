import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../domain/entities/home_banner.dart';

final homeBannersProvider = FutureProvider.autoDispose<List<HomeBanner>>((
  ref,
) async {
  final response = await ref
      .read(apiClientProvider)
      .get('/catalog/home-banners');
  final banners = response['banners'];
  if (banners is! List) return const <HomeBanner>[];
  return banners
      .whereType<Map<String, dynamic>>()
      .map(HomeBanner.fromJson)
      .where((banner) => banner.imageUrl.isNotEmpty)
      .toList(growable: false);
});
