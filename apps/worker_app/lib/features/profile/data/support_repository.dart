import 'package:dio/dio.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../domain/entities/worker_support_ticket.dart';

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<List<WorkerSupportTicket>> fetchMyTickets() async {
    try {
      final data = await _api.get('/support/tickets/me');
      final tickets = (data['tickets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkerSupportTicket.fromJson)
          .toList(growable: false);
      return tickets;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to load support tickets: $e');
    }
  }

  Future<void> submitTicket({
    required String subject,
    required String message,
    required String category,
  }) async {
    try {
      await _api.post(
        '/support/tickets',
        data: {
          'subject': subject,
          'message': message,
          'category': category,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to submit ticket: $e');
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
