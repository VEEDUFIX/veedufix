import 'package:dio/dio.dart';
import '../domain/entities/worker_wallet.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WorkerWalletRepository {
  WorkerWalletRepository(this._api);

  final ApiClient _api;

  Future<WorkerWallet> fetchWallet() async {
    try {
      final data = await _api.get('/worker/wallet');
      return WorkerWallet.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to load worker wallet.');
    }
  }

  Future<void> requestPayout(double amount, {String? upiId}) async {
    try {
      final payload = <String, dynamic>{
        'amount': amount,
        if (upiId != null) 'upiId': upiId,
      };

      // Use the unified payout endpoint. The backend handles this.
      await _api.post('/users/worker/wallet/payout', data: payload);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to request payout.');
    }
  }

  Future<List<int>> exportStatement() async {
    try {
      final response = await _api.dio.get<List<int>>(
        '/worker/earnings/export/csv',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const <int>[];
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to export statement.');
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
