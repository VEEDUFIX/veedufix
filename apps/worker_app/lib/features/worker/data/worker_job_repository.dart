import 'package:dio/dio.dart';
import 'worker_job_api.dart';

class WorkerJobRepository {
  WorkerJobRepository(this._api);

  final WorkerJobApi _api;

  Future<void> acceptJob(String bookingId) async {
    try {
      await _api.acceptJob(bookingId);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to accept job: $e');
    }
  }

  Future<void> declineJob(String offerId) async {
    try {
      await _api.declineJob(offerId);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to decline job: $e');
    }
  }

  Future<void> startEnRoute(String bookingId) async {
    try {
      await _api.startEnRoute(bookingId);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to start en-route: $e');
    }
  }

  Future<void> addSpareParts(String bookingId, Map<String, dynamic> data) async {
    try {
      await _api.addSpareParts(bookingId, data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to add spare parts: $e');
    }
  }

  Future<void> generateQuote(String bookingId, Map<String, dynamic> data) async {
    try {
      await _api.generateQuote(bookingId, data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to generate quote: $e');
    }
  }

  Exception _handleError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return Exception(message);
      }
    }
    return Exception(e.message ?? 'An unknown network error occurred');
  }
}
