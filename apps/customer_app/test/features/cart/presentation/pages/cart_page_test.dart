import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_app/features/cart/presentation/pages/cart_page.dart';
import 'package:customer_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

void main() {
  Widget createWidgetUnderTest(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: CartPage(),
      ),
    );
  }

  testWidgets('CartPage displays empty state when cart is empty', (WidgetTester tester) async {
    final container = ProviderContainer(); // Uses default empty CartNotifier

    await tester.pumpWidget(createWidgetUnderTest(container));

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Add services to get started'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsNothing);
  });

  testWidgets('CartPage displays items and calculates totals correctly', (WidgetTester tester) async {
    final container = ProviderContainer();
    
    // Add mock items to the cart
    final mockService1 = const CatalogService(
      id: 's1',
      categoryId: 'c1',
      subcategoryId: 'sc1',
      name: 'AC Repair',
      slug: 'ac-repair',
      code: 'AC01',
      startingPrice: 1000.0,
      estimatedDurationMins: 60,
    );
    
    final mockService2 = const CatalogService(
      id: 's2',
      categoryId: 'c1',
      subcategoryId: 'sc1',
      name: 'AC Gas Refill',
      slug: 'ac-gas',
      code: 'AC02',
      startingPrice: 2000.0,
      estimatedDurationMins: 90,
    );

    container.read(cartProvider.notifier).addService(mockService1);
    container.read(cartProvider.notifier).addService(mockService2);
    // Add second quantity of AC Repair
    container.read(cartProvider.notifier).addService(mockService1);

    await tester.pumpWidget(createWidgetUnderTest(container));
    await tester.pumpAndSettle();

    // Verify items are displayed
    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('AC Gas Refill'), findsOneWidget);
    
    // Verify quantities (1x Gas, 2x Repair)
    // The UI shows "2" for AC Repair and "1" for AC Gas Refill
    expect(find.text('2'), findsOneWidget); 
    expect(find.text('1'), findsOneWidget); 

    // Verify totals
    // Item Total = (1000 * 2) + (2000 * 1) = 4000
    // Tax (18%) = 720
    // Total = 4720
    expect(find.text('₹4000'), findsOneWidget);
    expect(find.text('₹720.00'), findsOneWidget);
    expect(find.text('₹4720.00'), findsOneWidget);
    
    expect(find.text('Proceed to Checkout'), findsOneWidget);
  });

  testWidgets('CartPage allows removing items', (WidgetTester tester) async {
    final container = ProviderContainer();
    
    final mockService = const CatalogService(
      id: 's1',
      categoryId: 'c1',
      subcategoryId: 'sc1',
      name: 'AC Repair',
      slug: 'ac-repair',
      code: 'AC01',
      startingPrice: 1000.0,
      estimatedDurationMins: 60,
    );

    container.read(cartProvider.notifier).addService(mockService);

    await tester.pumpWidget(createWidgetUnderTest(container));
    await tester.pumpAndSettle();

    expect(find.text('AC Repair'), findsOneWidget);

    // Tap the remove button (minus icon)
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    // Cart should now be empty
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('AC Repair'), findsNothing);
  });
}
