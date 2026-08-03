import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _favoritesStorageKey = 'customer_favorite_service_ids';

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  SharedPreferences? _prefs;

  @override
  Future<Set<String>> build() async {
    _prefs = await SharedPreferences.getInstance();
    return (_prefs!.getStringList(_favoritesStorageKey) ?? const <String>[]).toSet();
  }

  Future<void> toggleFavorite(String serviceId) async {
    final current = state.valueOrNull ?? await future;
    final next = {...current};
    if (!next.remove(serviceId)) {
      next.add(serviceId);
    }

    state = AsyncData(next);

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesStorageKey, next.toList()..sort());
  }

  bool isFavorite(String serviceId) => state.valueOrNull?.contains(serviceId) ?? false;
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

final isFavoriteProvider = Provider.family<bool, String>((ref, serviceId) {
  return ref.watch(favoritesProvider).maybeWhen(
        data: (favorites) => favorites.contains(serviceId),
        orElse: () => false,
      );
});
