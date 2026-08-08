import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:customer_app/features/home/presentation/widgets/home_featured_banner.dart';

void main() {
  group('HomeFeaturedBanner Widget Tests', () {
    testWidgets('renders title, subtitle, and action label correctly', (WidgetTester tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: HomeFeaturedBanner(
              title: 'Premium Services',
              subtitle: 'Book top-rated professionals',
              actionLabel: 'Book Now',
              onAction: () {
                actionTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify texts are rendered
      expect(find.text('Premium Services'), findsOneWidget);
      expect(find.text('Book top-rated professionals'), findsOneWidget);
      expect(find.text('Book Now'), findsOneWidget);

      // Verify action button works
      await tester.tap(find.text('Book Now'));
      await tester.pumpAndSettle();

      expect(actionTapped, isTrue);
    });
  });
}
