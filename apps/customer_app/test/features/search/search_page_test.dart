import 'package:customer_app/features/search/presentation/pages/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final width in [360.0, 375.0, 412.0]) {
    testWidgets('search layout fits at ${width.toInt()}dp', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_searchTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Trending services'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'debounces typed input and shows backend autocomplete suggestions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _searchTestApp(
          autocomplete: (query) => query == 'plumb'
              ? const [
                  CatalogSearchSuggestion(
                    label: 'Plumbing repair',
                    kind: 'SERVICE',
                    slug: 'plumbing-repair',
                    categorySlug: 'home-repair',
                    subcategorySlug: 'plumbing',
                  ),
                ]
              : const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'plumb');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Plumbing repair'), findsNothing);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();

      expect(find.text('Plumbing repair'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _searchTestApp({
  List<CatalogSearchSuggestion> Function(String query)? autocomplete,
}) {
  return ProviderScope(
    overrides: [
      homeCatalogProvider.overrideWith(
        (ref) async => const HomeCatalogResult(
          categories: [],
          trending: [],
          recommended: [],
        ),
      ),
      searchCatalogFilteredProvider.overrideWith(
        (ref, filters) async =>
            const CatalogSearchPageResult(items: [], total: 0),
      ),
      searchAutocompleteProvider.overrideWith(
        (ref, query) async => autocomplete?.call(query) ?? const [],
      ),
    ],
    child: const MaterialApp(home: SearchPage()),
  );
}
