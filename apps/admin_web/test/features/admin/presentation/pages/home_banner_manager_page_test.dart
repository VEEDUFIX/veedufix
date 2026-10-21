import 'package:admin_web/features/admin/presentation/pages/home_banner_manager_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class _TestApiClient implements ApiClient {
  _TestApiClient(this.dio);

  @override
  final Dio dio;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestDio implements Dio {
  final Map<String, dynamic> responses;

  _TestDio(this.responses);

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async =>
      Response<T>(
        requestOptions: RequestOptions(path: path),
        data: responses[path] as T,
        statusCode: 200,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _TestApiClient api;
  late _TestDio dio;

  setUp(() {
    dio = _TestDio({
      '/admin/catalog/home-banners': {
        'banners': [
          {
            'id': 'banner-1',
            'imageUrl': 'https://images.example/banner.jpg',
            'isActive': true,
            'sortOrder': 0,
            'destinationType': 'category',
            'destinationValue': '',
            'startsAt': null,
            'endsAt': null,
            'updatedAt': '2026-10-21T10:00:00.000Z',
          },
        ],
      },
      '/admin/catalog/home-banner-destinations': {
        'categories': [
          {'id': 'category-1', 'name': 'Electrical', 'slug': 'electrical'},
        ],
        'services': [
          {
            'id': 'service-1',
            'name': 'Switch repair',
            'slug': 'switch-repair',
            'category': {'name': 'Electrical'},
          },
        ],
      },
    });
    api = _TestApiClient(dio);
  });

  Widget buildApp() => ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: HomeBannerManagerPage()),
      );

  testWidgets('shows plain-language banner destination and lifecycle status',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Category search · all categories'), findsOneWidget);
    expect(find.text('Published'), findsWidgets);
    expect(find.text('category ·'), findsNothing);
    expect(find.text('Home banner'), findsNothing);
  });

  testWidgets('offers guided destination fields without a category slug',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add banner'));
    await tester.pumpAndSettle();

    expect(find.text('A · Banner image'), findsOneWidget);
    expect(find.text('B · Tap destination'), findsOneWidget);
    expect(find.text('C · Display settings'), findsOneWidget);
    expect(find.text('Choose a service'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category search').last);
    await tester.pumpAndSettle();

    expect(find.text('Choose a category (optional)'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
  });
}
