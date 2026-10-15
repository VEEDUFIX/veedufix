import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import 'package:customer_app/features/home/presentation/pages/home_page.dart';
import 'package:customer_app/features/home/domain/entities/home_banner.dart';
import 'package:customer_app/features/home/presentation/providers/home_banners_provider.dart';
import 'package:customer_app/features/home/presentation/widgets/home_category_tile.dart';
import 'package:customer_app/features/home/presentation/widgets/home_service_card.dart';

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
  group('HomePage Widget Tests', () {
    testWidgets('renders loading state while catalog loads', (tester) async {
      final catalogCompleter = Completer<HomeCatalogResult>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            homeCatalogProvider.overrideWith((ref) => catalogCompleter.future),
            homeCatalogSectionsProvider.overrideWith(
              (ref) async => const <HomeCatalogSection>[],
            ),
            homeBannersProvider.overrideWith(
              (ref) async => const <HomeBanner>[],
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      // We need to settle the auth controller future first, but since the other two are completing, pump once.
      await tester.pump();

      // Verify header is present
      expect(find.byType(HomeCategoryTile), findsNothing);
      expect(find.byType(HomeServiceCard), findsNothing);
    });

    testWidgets('renders catalog data when loaded', (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            homeCatalogProvider.overrideWith((ref) {
              return mockCatalog;
            }),
            homeCatalogSectionsProvider.overrideWith(
              (ref) async => const <HomeCatalogSection>[],
            ),
            homeBannersProvider.overrideWith(
              (ref) async => const <HomeBanner>[],
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _pumpHome(tester);

      // Check if categories are rendered (near the top)
      final categoryTileFinder = find.byType(
        HomeCategoryTile,
        skipOffstage: false,
      );
      expect(categoryTileFinder, findsOneWidget);
      expect(find.text('Cleaning', skipOffstage: false), findsWidgets);

      // Scroll down to services
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await _pumpHome(tester);

      // Check if services are rendered
      expect(find.byType(HomeServiceCard, skipOffstage: false), findsOneWidget);
      expect(find.text('Home Cleaning', skipOffstage: false), findsWidgets);
    });

    testWidgets('hides empty sections when data is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeEmptyAuthRepository()),
            homeCatalogProvider.overrideWith(
              (ref) => const HomeCatalogResult(
                categories: [],
                trending: [],
                recommended: [],
              ),
            ),
            homeCatalogSectionsProvider.overrideWith(
              (ref) async => const <HomeCatalogSection>[],
            ),
            homeBannersProvider.overrideWith(
              (ref) async => const <HomeBanner>[],
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await _pumpHome(tester);

      // Empty sections should be hidden — no empty state text
      expect(
        find.text('No featured categories right now', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text('No featured services right now', skipOffstage: false),
        findsNothing,
      );

      // The home page keeps its content lean when no catalog content exists.
      expect(find.text('Why Veedufix?', skipOffstage: false), findsNothing);
    });
  });
}

Future<void> _pumpHome(WidgetTester tester) async {
  // HomeSearchBar rotates its placeholder on a periodic timer, so pumpAndSettle never completes.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
