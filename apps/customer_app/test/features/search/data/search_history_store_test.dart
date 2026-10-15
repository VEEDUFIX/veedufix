import 'package:customer_app/features/search/data/search_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'stores recent searches locally, newest first, without duplicates',
    () async {
      final store = CustomerSearchHistoryStore();

      await store.add('AC repair');
      await store.add('Plumbing');
      await store.add('ac REPAIR');

      expect(await store.load(), ['ac REPAIR', 'Plumbing']);
    },
  );

  test('supports removing one item and clearing all local history', () async {
    final store = CustomerSearchHistoryStore();
    await store.add('AC repair');
    await store.add('Plumbing');

    await store.remove('Plumbing');
    expect(await store.load(), ['AC repair']);

    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('caps history and rejects overlong or empty queries', () async {
    final store = CustomerSearchHistoryStore();
    for (var index = 0; index < 10; index++) {
      await store.add('service $index');
    }
    await store.add('  ');
    await store.add(List.filled(121, 'x').join());

    final history = await store.load();
    expect(history, hasLength(CustomerSearchHistoryStore.maxEntries));
    expect(history.first, 'service 9');
  });
}
