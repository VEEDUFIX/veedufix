import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/notification_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

export '../../domain/entities/notification_entity.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  try {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.get('/notifications');
    final list = response['notifications'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
});

final notificationsUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.get('/notifications');
    return (response['unreadCount'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});
