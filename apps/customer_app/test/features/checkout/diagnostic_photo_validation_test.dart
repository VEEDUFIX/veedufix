import 'dart:typed_data';

import 'package:customer_app/features/checkout/data/diagnostic_photo_validation.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;

  setUp(() => api = _MockApiClient());

  testWidgets('booking photo gallery displays a recoverable empty state', (
    tester,
  ) async {
    when(
      () => api.get('/bookings/booking-1/diagnostic-photos'),
    ).thenAnswer((_) async => <String, dynamic>{'photos': <dynamic>[]});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(
            body: BookingDiagnosticPhotosSection(
              bookingId: 'booking-1',
              showEmpty: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No issue photos'), findsOneWidget);
  });

  testWidgets('booking photo gallery shows a retry action on load failure', (
    tester,
  ) async {
    when(
      () => api.get('/bookings/booking-1/diagnostic-photos'),
    ).thenThrow(Exception('offline'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(
            body: BookingDiagnosticPhotosSection(
              bookingId: 'booking-1',
              showEmpty: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Issue photos unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('issue photo thumbnail exposes an accessible button label', (
    tester,
  ) async {
    when(() => api.get('/bookings/booking-1/diagnostic-photos')).thenAnswer(
      (_) async => <String, dynamic>{
        'photos': <dynamic>[
          <String, dynamic>{
            'id': 'photo-1',
            'url': 'https://private.example/photo',
            'bytes': 4,
            'createdAt': '2026-10-14T00:00:00.000Z',
          },
        ],
      },
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(
            body: BookingDiagnosticPhotosSection(bookingId: 'booking-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Open issue photo'), findsOneWidget);
    semantics.dispose();
  });

  test('refreshes signed photo URLs before the five-minute expiry', () {
    fakeAsync((async) {
      var fetchCount = 0;
      when(() => api.get('/bookings/booking-1/diagnostic-photos')).thenAnswer((
        _,
      ) async {
        fetchCount++;
        return <String, dynamic>{
          'photos': <dynamic>[
            <String, dynamic>{
              'id': 'photo-1',
              'url': 'https://private.example/photo-$fetchCount',
              'bytes': 4,
              'createdAt': '2026-10-14T00:00:00.000Z',
            },
          ],
        };
      });
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      final subscription = container.listen(
        bookingDiagnosticPhotosProvider('booking-1'),
        (_, __) {},
      );
      async.flushMicrotasks();
      expect(fetchCount, 1);

      async.elapse(const Duration(seconds: 241));
      async.flushMicrotasks();
      expect(fetchCount, 2);

      subscription.close();
      container.dispose();
    });
  });

  test(
    'Customer image validator accepts valid JPEG and PNG and rejects invalid size/type',
    () {
      expect(
        validateDiagnosticPhotoBytes(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
        ),
        isNull,
      );
      expect(
        validateDiagnosticPhotoBytes(
          Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        ),
        isNull,
      );
      expect(
        validateDiagnosticPhotoBytes(Uint8List.fromList([0x47, 0x49, 0x46])),
        isNotNull,
      );
      expect(
        validateDiagnosticPhotoBytes(Uint8List(diagnosticPhotoMaxBytes + 1)),
        isNotNull,
      );
    },
  );
}
