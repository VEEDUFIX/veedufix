import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CheckoutRequestKeyStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureCheckoutRequestKeyStorage
    implements CheckoutRequestKeyStorage {
  FlutterSecureCheckoutRequestKeyStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class CheckoutRequestKeyStore {
  CheckoutRequestKeyStore({
    required CheckoutRequestKeyStorage storage,
    String Function()? createKey,
  }) : _storage = storage,
       _createKey = createKey ?? _createRandomKey;

  static const _keyPrefix = 'customer_rebook_checkout_request_';

  final CheckoutRequestKeyStorage _storage;
  final String Function() _createKey;

  Future<String> getOrCreate({
    required String customerId,
    required String sourceBookingId,
  }) async {
    final storageKey = _storageKey(customerId, sourceBookingId);
    final savedKey = await _storage.read(storageKey);
    if (savedKey != null && savedKey.isNotEmpty) return savedKey;

    final key = _createKey();
    await _storage.write(storageKey, key);
    return key;
  }

  Future<void> clear({
    required String customerId,
    required String sourceBookingId,
  }) => _storage.delete(_storageKey(customerId, sourceBookingId));

  String _storageKey(String customerId, String sourceBookingId) {
    final identity = base64Url.encode(
      utf8.encode('$customerId:$sourceBookingId'),
    );
    return '$_keyPrefix$identity';
  }

  static String _createRandomKey() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
}
