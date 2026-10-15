import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/booking/presentation/data/rebook_options.dart';

void main() {
  group('RebookOptions', () {
    test('restores only current selection identifiers and ignores old prices', () {
      final options = RebookOptions.fromJson({
        'sourceBookingId': 'booking-1',
        'sourceBookingCode': 'BK-1',
        'canRebook': true,
        'addressMatched': true,
        'preferredAddressId': 'saved-address-1',
        'items': [
          {
            'serviceId': 'service-1',
            'serviceName': 'AC service',
            'serviceSlug': 'ac-service',
            'quantity': 2,
            'variantId': 'variant-current',
            'addonIds': ['addon-current'],
            'historicalUnitPrice': 999999,
          },
        ],
      });

      expect(options.canRebook, isTrue);
      expect(options.preferredAddressId, 'saved-address-1');
      expect(options.items.single.quantity, 2);
      expect(options.items.single.variantId, 'variant-current');
      expect(options.items.single.addonIds, ['addon-current']);
    });

    test('preserves a useful non-rebookable reason and normalizes invalid quantity', () {
      final options = RebookOptions.fromJson({
        'sourceBookingId': 'booking-2',
        'sourceBookingCode': 'BK-2',
        'canRebook': false,
        'reason': 'Resolve the active claim first.',
        'items': [
          {
            'serviceId': 'service-1',
            'quantity': 0,
            'addonIds': <String>[],
          },
        ],
      });

      expect(options.canRebook, isFalse);
      expect(options.reason, contains('active claim'));
      expect(options.items.single.quantity, 1);
    });
  });
}
