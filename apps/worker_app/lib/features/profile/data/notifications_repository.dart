import 'package:dio/dio.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<void> markAllAsRead() async {
    try {
      await _api.post('/notifications/mark-all-read');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.patch('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
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
