import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:worker_app/features/worker/presentation/pages/jobs_page.dart';

void main() {
  Widget buildApp(List<Override> overrides) {
    final router = GoRouter(
      initialLocation: '/?tab=incoming',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const JobsPage(),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('JobsPage Widget Tests', () {

    testWidgets('renders empty state when no jobs', (tester) async {
      await tester.pumpWidget(buildApp([
        workerJobsProvider('incoming').overrideWith((ref) => Future.value([])),
        workerJobsProvider('accepted').overrideWith((ref) => Future.value([])),
        workerJobsProvider('active').overrideWith((ref) => Future.value([])),
        workerJobsProvider('completed').overrideWith((ref) => Future.value([])),
      ]));

      await tester.pumpAndSettle();

      expect(find.text('No incoming jobs'), findsOneWidget);
      expect(find.text('You have no incoming jobs at the moment.'), findsOneWidget);
    });

    testWidgets('renders jobs correctly', (tester) async {
      final mockJob = WorkerJob(
        bookingId: 'booking1',
        code: 'BK-1234',
        status: 'pending',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        totalAmount: 100.0,
        serviceId: 'service1',
        serviceName: 'House Cleaning',
        addressLabel: 'Home',
        customerName: 'Alice',
      );

      await tester.pumpWidget(buildApp([
        workerJobsProvider('incoming').overrideWith((ref) => Future.value([mockJob])),
        workerJobsProvider('accepted').overrideWith((ref) => Future.value([])),
        workerJobsProvider('active').overrideWith((ref) => Future.value([])),
        workerJobsProvider('completed').overrideWith((ref) => Future.value([])),
      ]));

      await tester.pumpAndSettle();

      expect(find.text('House Cleaning'), findsWidgets);
      expect(find.text('Alice'), findsWidgets);
    });
  });
}
