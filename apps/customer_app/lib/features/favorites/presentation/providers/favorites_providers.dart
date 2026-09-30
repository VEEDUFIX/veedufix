import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _guestFavoritesStorageKey = 'customer_favorite_service_ids_guest';
const _favoritesStoragePrefix = 'customer_favorite_service_ids_';

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  SharedPreferences? _prefs;
  String _storageKey = _guestFavoritesStorageKey;
  Future<void> _writeQueue = Future<void>.value();

  @override
  Future<Set<String>> build() async {
    final userId = ref.watch(
      authControllerProvider.select((auth) => auth.valueOrNull?.user.id),
    );
    _storageKey = userId == null
        ? _guestFavoritesStorageKey
        : '$_favoritesStoragePrefix$userId';
    _prefs = await SharedPreferences.getInstance();
    return (_prefs!.getStringList(_storageKey) ?? const <String>[]).toSet();
  }

  Future<void> toggleFavorite(String serviceId) async {
    final normalizedId = serviceId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(serviceId, 'serviceId', 'Must not be empty.');
    }

    await future;
    final key = _storageKey;
    final result = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        final prefs = _prefs ??= await SharedPreferences.getInstance();
        final next = (prefs.getStringList(key) ?? const <String>[]).toSet();
        if (!next.remove(normalizedId)) {
          next.add(normalizedId);
        }

        final saved = await prefs.setStringList(key, next.toList()..sort());
        if (!saved) {
          throw StateError('Could not save favorites on this device.');
        }
        if (_storageKey == key) {
          state = AsyncData(next);
        }
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  bool isFavorite(String serviceId) =>
      state.valueOrNull?.contains(serviceId) ?? false;
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);

final isFavoriteProvider = Provider.family<bool, String>((ref, serviceId) {
  return ref
      .watch(favoritesProvider)
      .maybeWhen(
        data: (favorites) => favorites.contains(serviceId),
        orElse: () => false,
      );
});
