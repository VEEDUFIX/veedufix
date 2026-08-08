import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_web/features/admin/presentation/pages/customer_management_page.dart';

void main() {
  Widget buildApp(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: CustomerManagementPage(),
      ),
    );
  }

  group('CustomerManagementPage Widget Tests', () {
    testWidgets('renders empty state when no customers', (tester) async {
      await tester.pumpWidget(buildApp([
        adminCustomersProvider('').overrideWith((ref) => Future.value([])),
      ]));

      await tester.pumpAndSettle();

      expect(find.text('No customers found'), findsOneWidget);
      expect(find.text('Try a different search term.'), findsOneWidget);
    });

    testWidgets('renders customers correctly', (tester) async {
      final mockCustomer = AdminCustomer(
        id: 'c1',
        name: 'John Doe',
        phone: '+1234567890',
        totalBookings: 5,
        totalSpend: 250.0,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await tester.pumpWidget(buildApp([
        adminCustomersProvider('').overrideWith((ref) => Future.value([mockCustomer])),
      ]));

      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsWidgets);
      expect(find.text('+1234567890'), findsWidgets);
    });
  });
}
