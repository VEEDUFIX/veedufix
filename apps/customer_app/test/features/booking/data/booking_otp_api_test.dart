import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/booking/presentation/data/booking_otp_api.dart';

void main() {
  group('BookingOtpDetails JSON Parsing Tests', () {
    test('Parses complete valid backend response correctly', () {
      final jsonResponse = {
        'booking': {
          'id': 'bkg_123',
          'code': 'BKG-12345',
          'serviceName': 'AC Repair',
          'customerName': 'John Doe',
          'addressLabel': 'Home, Chennai',
          'status': 'IN_PROGRESS',
          'afterPhotos': ['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg'],
          'worker': {
            'name': 'Bob the Builder',
            'avatarUrl': 'https://example.com/bob.jpg',
          }
        }
      };

      final details = BookingOtpDetails.fromJson(jsonResponse);

      expect(details.bookingId, 'bkg_123');
      expect(details.bookingCode, 'BKG-12345');
      expect(details.serviceName, 'AC Repair');
      expect(details.customerName, 'John Doe');
      expect(details.locationLabel, 'Home, Chennai');
      expect(details.statusLabel, 'IN_PROGRESS');
      expect(details.afterPhotoUrls, ['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg']);
      expect(details.workerName, 'Bob the Builder');
      expect(details.workerPhotoUrl, 'https://example.com/bob.jpg');
    });

    test('Parses minimal/empty backend response without crashing', () {
      final jsonResponse = <String, dynamic>{};

      final details = BookingOtpDetails.fromJson(jsonResponse);

      expect(details.bookingId, '');
      expect(details.bookingCode, '');
      expect(details.serviceName, 'Service booking');
      expect(details.customerName, 'Customer');
      expect(details.workerName, 'Your professional');
      expect(details.afterPhotoUrls, isEmpty);
      expect(details.workerPhotoUrl, isNull);
      expect(details.locationLabel, isNull);
      expect(details.statusLabel, isNull);
    });
  });
}
