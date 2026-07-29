import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({});

  void toggleFavorite(String serviceId) {
    if (state.contains(serviceId)) {
      state = {...state}..remove(serviceId);
    } else {
      state = {...state, serviceId};
    }
  }

  bool isFavorite(String serviceId) => state.contains(serviceId);
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

final isFavoriteProvider = Provider.family<bool, String>((ref, serviceId) {
  return ref.watch(favoritesProvider).contains(serviceId);
});
