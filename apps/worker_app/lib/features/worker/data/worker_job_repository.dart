import 'package:dio/dio.dart';
import 'worker_job_api.dart';

class WorkerJobActionError implements Exception {
  const WorkerJobActionError(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class WorkerJobRepository {
  WorkerJobRepository(this._api);

  final WorkerJobApi _api;

  Future<void> acceptJob(String bookingId) async {
    try {
      await _api.acceptJob(bookingId);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw const WorkerJobActionError(
          'Could not accept this job. Please try again.');
    }
  }

  Future<void> declineJob(String offerId) async {
    try {
      await _api.declineJob(offerId);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw const WorkerJobActionError(
          'Could not decline this job. Please try again.');
    }
  }

  Future<void> startEnRoute(String bookingId) async {
    try {
      await _api.startEnRoute(bookingId);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to start en-route.');
    }
  }

  Future<void> addSpareParts(
      String bookingId, Map<String, dynamic> data) async {
    try {
      await _api.addSpareParts(bookingId, data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to add spare parts.');
    }
  }

  Future<void> generateQuote(
      String bookingId, Map<String, dynamic> data) async {
    try {
      await _api.generateQuote(bookingId, data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to generate quote.');
    }
  }

  WorkerJobActionError _handleError(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 409 || statusCode == 410) {
      return const WorkerJobActionError(
        'This job offer is no longer available. Refresh the list to see current jobs.',
        statusCode: 409,
      );
    }
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return WorkerJobActionError(message, statusCode: statusCode);
      }
    }
    return WorkerJobActionError(
      e.message ??
          'A network error occurred. Check your connection and try again.',
      statusCode: statusCode,
    );
  }
}
