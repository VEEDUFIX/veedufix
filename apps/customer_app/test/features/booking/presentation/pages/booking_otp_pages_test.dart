import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:customer_app/features/booking/presentation/pages/arrival_otp_page.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApiClient;
  late MockDio mockDio;

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);
  });

  Widget buildApp(Widget child) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('ArrivalOtpPage', () {
    testWidgets('shows loading state initially', (tester) async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return Response(
          requestOptions: RequestOptions(path: ''),
          data: {},
        );
      });

      await tester.pumpWidget(buildApp(const ArrivalOtpPage(bookingId: '123')));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state when API fails', (tester) async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(requestOptions: RequestOptions(path: ''), error: 'Network error'),
      );

      await tester.pumpWidget(buildApp(const ArrivalOtpPage(bookingId: '123')));
      await tester.pumpAndSettle();

      expect(find.text('Arrival code unavailable'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('displays OTP correctly on success', (tester) async {
      when(() => mockDio.get<Map<String, dynamic>>('/bookings/123')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'id': '123',
            'code': 'BK-123',
            'serviceName': 'Plumbing',
            'customerName': 'John Doe',
            'worker': {
              'name': 'Jane Smith'
            }
          },
        ),
      );

      when(() => mockDio.get<Map<String, dynamic>>('/bookings/123/arrival-otp')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'bookingId': '123',
            'otp': '123456',
            'otpExpiresAt': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
          },
        ),
      );

      await tester.pumpWidget(buildApp(const ArrivalOtpPage(bookingId: '123')));
      await tester.pumpAndSettle();

      expect(find.text('123456'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('Plumbing'), findsOneWidget);
    });
  });
}
