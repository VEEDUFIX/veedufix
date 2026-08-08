import 'package:dio/dio.dart';
import '../domain/entities/worker_earnings.dart';
import 'worker_earnings_api.dart';

class WorkerEarningsRepository {
  WorkerEarningsRepository(this._api);

  final WorkerEarningsApi _api;

  Future<WorkerEarningsSummary> fetchSummary() async {
    try {
      return await _api.fetchSummary();
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to load earnings summary: $e');
    }
  }

  Future<WorkerEarningsTransactionPage> fetchTransactions({
    int page = 1,
    int limit = 6,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      return await _api.fetchTransactions(
        page: page,
        limit: limit,
        status: status,
        fromDate: fromDate,
        toDate: toDate,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to load earnings transactions: $e');
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
