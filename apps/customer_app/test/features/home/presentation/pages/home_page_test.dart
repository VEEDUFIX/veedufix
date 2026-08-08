import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import 'package:customer_app/features/home/presentation/pages/home_page.dart';
import 'package:customer_app/features/home/presentation/widgets/home_category_chips.dart';
import 'package:customer_app/features/home/presentation/widgets/home_service_grid.dart';
import 'package:customer_app/features/home/presentation/widgets/home_professionals_section.dart';

class FakeAuthRepository extends Fake implements AuthRepository {
  @override
  Future<AuthSession?> restoreSession() async {
    return const AuthSession(
      user: AuthUser(
        id: 'user1',
        role: 'CUSTOMER',
        name: 'Alice',
        email: null,
        phone: '+919876543210',
        avatarUrl: null,
        cityId: 'city1',
      ),
      accessToken: 'token',
      refreshToken: 'refresh',
    );
  }
}

class FakeEmptyAuthRepository extends Fake implements AuthRepository {
  @override
  Future<AuthSession?> restoreSession() async {
    return null;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(const HomeCatalogResult(categories: [], trending: [], recommended: []));
    registerFallbackValue(const <HomeProfessional>[]);
  });

  group('HomePage Widget Tests', () {
    testWidgets('renders shimmer while loading catalog and professionals',
        (tester) async {
      final catalogCompleter = Completer<HomeCatalogResult>();
      final professionalsCompleter = Completer<List<HomeProfessional>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            homeCatalogProvider.overrideWith((ref) => catalogCompleter.future),
            homeProfessionalsProvider.overrideWith((ref) => professionalsCompleter.future),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      // We need to settle the auth controller future first, but since the other two are completing, pump once.
      await tester.pump();

      // Verify header is present
      expect(find.text('What service do you need?'), findsOneWidget);
      expect(find.text('Quick categories'), findsOneWidget);

      expect(find.byType(CategoryChip), findsNothing);
      expect(find.byType(HomeServiceCard), findsNothing);
      expect(find.byType(ProfessionalCard), findsNothing);
    });

    testWidgets('renders data when catalog and professionals are loaded',
        (tester) async {
      const mockCatalog = HomeCatalogResult(
        categories: [
          CatalogCategory(
            id: 'cat1',
            name: 'Cleaning',
            slug: 'cleaning',
            iconUrl: null,
            seoTitle: null,
            seoDescription: null,
            sortOrder: 1,
            isActive: true,
            featured: true,
            popular: false,
            subcategories: [],
            serviceCount: 1,
            translations: [],
          ),
        ],
        trending: [
          CatalogService(
            id: 'serv1',
            categoryId: 'cat1',
            subcategoryId: 'sub1',
            name: 'Home Cleaning',
            slug: 'home-cleaning',
            code: 'CLN-101',
            startingPrice: 500.0,
            estimatedDurationMins: 120,
            isActive: true,
          ),
        ],
        recommended: [],
      );

      const mockProfessionals = [
        HomeProfessional(
          name: 'John Cleaning Services',
          role: 'Cleaner',
          experience: '150 jobs',
          rating: 4.8,
          distance: 'Nearby',
          price: 'Book for quote',
          verified: true,
          accent: Colors.green,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            homeCatalogProvider.overrideWith((ref) {
              return mockCatalog;
            }),
            homeProfessionalsProvider.overrideWith((ref) => mockProfessionals),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Check if categories are rendered (near the top)
      final categoryChipFinder = find.byType(CategoryChip, skipOffstage: false);
      expect(categoryChipFinder, findsOneWidget);
      expect(find.text('Cleaning', skipOffstage: false), findsWidgets);

      // Scroll down to services
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Check if services are rendered
      expect(find.byType(HomeServiceCard, skipOffstage: false), findsOneWidget);
      expect(find.text('Home Cleaning', skipOffstage: false), findsWidgets);

      // Scroll down to professionals
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pumpAndSettle();

      // Check if professionals are rendered
      expect(find.byType(ProfessionalCard, skipOffstage: false), findsOneWidget);
      expect(find.text('John Cleaning Services', skipOffstage: false), findsWidgets);
    });

    testWidgets('renders empty state when data is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeEmptyAuthRepository()),
            homeCatalogProvider.overrideWith((ref) => 
                  const HomeCatalogResult(categories: [], trending: [], recommended: []),
                ),
            homeProfessionalsProvider.overrideWith((ref) => const <HomeProfessional>[]),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No featured categories right now', skipOffstage: false), findsOneWidget);
      
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('No featured services right now', skipOffstage: false), findsOneWidget);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.text('No professionals available right now.', skipOffstage: false), findsOneWidget);
    });
  });
}
