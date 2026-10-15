import 'package:customer_app/features/checkout/data/checkout_request_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CheckoutRequestKeyStore', () {
    test(
      'reuses the request key after a new store instance is created',
      () async {
        final storage = _MemoryCheckoutRequestKeyStorage();
        var sequence = 0;
        String createKey() => 'request-${++sequence}';

        final firstAppSession = CheckoutRequestKeyStore(
          storage: storage,
          createKey: createKey,
        );
        final keyBeforeRestart = await firstAppSession.getOrCreate(
          customerId: 'customer-1',
          sourceBookingId: 'booking-1',
        );

        final afterRestart = CheckoutRequestKeyStore(
          storage: storage,
          createKey: createKey,
        );
        final keyAfterRestart = await afterRestart.getOrCreate(
          customerId: 'customer-1',
          sourceBookingId: 'booking-1',
        );

        expect(keyAfterRestart, keyBeforeRestart);
        expect(sequence, 1);
      },
    );

    test('isolates keys by customer and source booking', () async {
      var sequence = 0;
      final store = CheckoutRequestKeyStore(
        storage: _MemoryCheckoutRequestKeyStorage(),
        createKey: () => 'request-${++sequence}',
      );

      final first = await store.getOrCreate(
        customerId: 'customer-1',
        sourceBookingId: 'booking-1',
      );
      final anotherCustomer = await store.getOrCreate(
        customerId: 'customer-2',
        sourceBookingId: 'booking-1',
      );
      final anotherBooking = await store.getOrCreate(
        customerId: 'customer-1',
        sourceBookingId: 'booking-2',
      );

      expect({first, anotherCustomer, anotherBooking}.length, 3);
    });

    test(
      'clearing a completed rebooking permits a later new attempt',
      () async {
        var sequence = 0;
        final store = CheckoutRequestKeyStore(
          storage: _MemoryCheckoutRequestKeyStorage(),
          createKey: () => 'request-${++sequence}',
        );
        const customerId = 'customer-1';
        const sourceBookingId = 'booking-1';

        final completedKey = await store.getOrCreate(
          customerId: customerId,
          sourceBookingId: sourceBookingId,
        );
        await store.clear(
          customerId: customerId,
          sourceBookingId: sourceBookingId,
        );
        final laterAttemptKey = await store.getOrCreate(
          customerId: customerId,
          sourceBookingId: sourceBookingId,
        );

        expect(laterAttemptKey, isNot(completedKey));
      },
    );
  });
}

class _MemoryCheckoutRequestKeyStorage implements CheckoutRequestKeyStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
