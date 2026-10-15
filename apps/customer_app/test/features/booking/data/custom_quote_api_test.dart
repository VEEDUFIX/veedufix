import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer_app/features/booking/data/custom_quote_api.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient client;
  late CustomQuoteApi api;

  setUp(() {
    client = MockApiClient();
    api = CustomQuoteApi(client);
  });

  test(
    'responds through the backend route using the accept boolean contract',
    () async {
      when(
        () => client.post(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => <String, dynamic>{'ok': true});

      await api.respond('booking-123', accept: true);

      verify(
        () => client.post(
          '/bookings/booking-123/custom-quote/respond',
          data: {'accept': true},
        ),
      ).called(1);
    },
  );

  test('sends false through the same response route for rejection', () async {
    when(
      () => client.post(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => <String, dynamic>{'ok': true});

    await api.respond('booking-123', accept: false);

    verify(
      () => client.post(
        '/bookings/booking-123/custom-quote/respond',
        data: {'accept': false},
      ),
    ).called(1);
  });
}
