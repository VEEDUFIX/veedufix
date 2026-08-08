import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_app/features/wallet/presentation/pages/wallet_page.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

void main() {
  Widget createWidgetUnderTest(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: WalletPage(),
      ),
    );
  }

  testWidgets('WalletPage displays loading spinner initially', (WidgetTester tester) async {
    final completer = Completer<WalletDetails>();
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith((ref) => completer.future),
      ],
    );

    await tester.pumpWidget(createWidgetUnderTest(container));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('WalletPage displays balance and empty state when no transactions', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith((ref) async => const WalletDetails(
              balance: 1500.50,
              referralCode: 'VEEDU123',
              totalReferrals: 0,
              referralEarnings: 0.0,
              transactions: [],
            )),
      ],
    );

    await tester.pumpWidget(createWidgetUnderTest(container));
    await tester.pumpAndSettle();

    expect(find.text('₹1500.50'), findsOneWidget);
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('WalletPage displays transaction history', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith((ref) async => WalletDetails(
              balance: 2000.0,
              referralCode: 'VEEDU123',
              totalReferrals: 1,
              referralEarnings: 500.0,
              transactions: [
                WalletTransaction(
                  id: 'tx1',
                  type: 'CREDIT',
                  amount: 500.0,
                  referenceType: 'REFERRAL_BONUS',
                  createdAt: DateTime(2026, 8, 1),
                ),
              ],
            )),
      ],
    );

    await tester.pumpWidget(createWidgetUnderTest(container));
    await tester.pumpAndSettle();

    expect(find.text('₹2000.00'), findsOneWidget);
    expect(find.text('REFERRAL_BONUS'), findsOneWidget);
    expect(find.text('+₹500.00'), findsOneWidget);
    expect(find.text('No transactions yet'), findsNothing);
  });

  testWidgets('WalletPage displays error state', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith((ref) => Future.error(Exception('Network Error'))),
      ],
    );

    await tester.pumpWidget(createWidgetUnderTest(container));
    await tester.pumpAndSettle();

    expect(find.textContaining('Error loading wallet'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
