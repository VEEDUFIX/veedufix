import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
  });

  test('walletProvider fetches balance and transactions successfully', () async {
    when(() => mockApiClient.get('/wallet/')).thenAnswer((_) async => {
          'balance': 1500.0,
          'referralCode': 'VEEDU123',
          'transactions': [
            {
              'id': 'tx1',
              'amount': 500.0,
              'type': 'CREDIT',
              'referenceType': 'REFERRAL_BONUS',
              'createdAt': '2026-08-01T10:00:00Z',
            }
          ]
        });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    final wallet = await container.read(walletProvider.future);

    expect(wallet.balance, 1500.0);
    expect(wallet.referralCode, 'VEEDU123');
    expect(wallet.transactions.length, 1);
    expect(wallet.transactions.first.amount, 500.0);
    expect(wallet.transactions.first.type, 'CREDIT');
  });

  test('walletProvider handles empty transactions', () async {
    when(() => mockApiClient.get('/wallet/')).thenAnswer((_) async => {
          'balance': 0.0,
          'referralCode': 'NEW123',
          'transactions': []
        });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    final wallet = await container.read(walletProvider.future);

    expect(wallet.balance, 0.0);
    expect(wallet.transactions, isEmpty);
  });

  test('walletProvider throws error on API failure', () async {
    when(() => mockApiClient.get('/wallet/')).thenThrow(Exception('Internal Server Error'));

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );

    expect(
      () => container.read(walletProvider.future),
      throwsA(isA<Exception>()),
    );
  });
}
