import 'package:shared_preferences/shared_preferences.dart';

class CustomerSearchHistoryStore {
  CustomerSearchHistoryStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const storageKey = 'customer_recent_catalog_searches_v1';
  static const maxEntries = 8;

  final SharedPreferences? _preferences;

  Future<List<String>> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    return (preferences.getStringList(storageKey) ?? const <String>[])
        .where((query) => query.trim().isNotEmpty)
        .take(maxEntries)
        .toList(growable: false);
  }

  Future<void> add(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty || normalized.length > 120) return;
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final values = preferences.getStringList(storageKey) ?? <String>[];
    values.removeWhere(
      (value) => value.toLowerCase() == normalized.toLowerCase(),
    );
    values.insert(0, normalized);
    await preferences.setStringList(
      storageKey,
      values.take(maxEntries).toList(),
    );
  }

  Future<void> remove(String query) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final values = preferences.getStringList(storageKey) ?? <String>[];
    values.removeWhere((value) => value == query);
    await preferences.setStringList(storageKey, values);
  }

  Future<void> clear() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }

  Future<void> replace(List<String> queries) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final values = <String>[];
    for (final query in queries) {
      final normalized = query.trim();
      if (normalized.isEmpty || normalized.length > 120) continue;
      if (values.any(
        (value) => value.toLowerCase() == normalized.toLowerCase(),
      )) {
        continue;
      }
      values.add(normalized);
      if (values.length == maxEntries) break;
    }
    await preferences.setStringList(storageKey, values);
  }
}
