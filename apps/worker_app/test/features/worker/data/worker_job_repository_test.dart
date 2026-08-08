import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:worker_app/features/worker/data/worker_job_api.dart';
import 'package:worker_app/features/worker/data/worker_job_repository.dart';

class MockWorkerJobApi extends Mock implements WorkerJobApi {}

void main() {
  late MockWorkerJobApi mockApi;
  late WorkerJobRepository repository;

  setUp(() {
    mockApi = MockWorkerJobApi();
    repository = WorkerJobRepository(mockApi);
  });

  group('WorkerJobRepository', () {
    const bookingId = 'booking-123';
    
    test('acceptJob completes successfully when API succeeds', () async {
      when(() => mockApi.acceptJob(bookingId)).thenAnswer((_) async {});

      await expectLater(repository.acceptJob(bookingId), completes);
      verify(() => mockApi.acceptJob(bookingId)).called(1);
    });

    test('acceptJob throws custom Exception when API returns DioException with message', () async {
      when(() => mockApi.acceptJob(bookingId)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            data: {'message': 'Job already accepted by someone else'},
          ),
        ),
      );

      await expectLater(
        repository.acceptJob(bookingId),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Job already accepted by someone else'))),
      );
    });

    test('acceptJob throws generic Exception when API throws non-DioException', () async {
      when(() => mockApi.acceptJob(bookingId)).thenThrow(Exception('Unknown error'));

      await expectLater(
        repository.acceptJob(bookingId),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unknown error'))),
      );
    });

    test('generateQuote passes correct data to API', () async {
      final quoteData = {
        'items': [
          {'name': 'Wire', 'price': 500, 'quantity': 1}
        ],
        'laborCharges': 200,
      };

      when(() => mockApi.generateQuote(bookingId, quoteData)).thenAnswer((_) async {});

      await expectLater(repository.generateQuote(bookingId, quoteData), completes);
      verify(() => mockApi.generateQuote(bookingId, quoteData)).called(1);
    });
    
    test('generateQuote handles DioException correctly', () async {
      final quoteData = {'invalid': 'data'};

      when(() => mockApi.generateQuote(bookingId, quoteData)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            data: {'message': 'Invalid quote structure'},
          ),
        ),
      );

      await expectLater(
        repository.generateQuote(bookingId, quoteData),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Invalid quote structure'))),
      );
    });
  });
}
