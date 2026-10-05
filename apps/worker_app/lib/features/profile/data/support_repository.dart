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
    } catch (_) {
      throw Exception('Failed to load support tickets.');
    }
  }

  Future<WorkerSupportThread> fetchTicketThread(String ticketId) async {
    try {
      final data = await _api.get(
        '/support/tickets/${Uri.encodeComponent(ticketId)}',
      );
      final ticket = data['ticket'];
      if (ticket is! Map<String, dynamic>) {
        throw const FormatException('Support ticket data is unavailable.');
      }
      return WorkerSupportThread.fromJson(ticket);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to load support conversation.');
    }
  }

  Future<void> replyToTicket({
    required String ticketId,
    required String message,
  }) async {
    try {
      await _api.post(
        '/support/tickets/${Uri.encodeComponent(ticketId)}/replies',
        data: {'message': message},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to send support reply.');
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
        data: {'subject': subject, 'message': message, 'category': category},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (_) {
      throw Exception('Failed to submit ticket.');
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
