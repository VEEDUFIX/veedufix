import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/notifications_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Notifications'),
          actions: [
            if (notificationsAsync.valueOrNull?.any((item) => !item.isRead) ==
                true)
              TextButton(
                onPressed: () => _markAllNotificationsRead(context, ref),
                child: const Text('Mark all read'),
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Jobs'),
              Tab(text: 'Earnings'),
              Tab(text: 'System'),
            ],
          ),
        ),
        body: notificationsAsync.when(
          data: (notifications) {
            return TabBarView(
              children: [
                _NotificationList(
                  notifications: notifications,
                  onRefresh: () async =>
                      ref.refresh(notificationsProvider.future),
                  onOpen: (item) => _openWorkerNotification(context, ref, item),
                  onDismiss: (notificationId) =>
                      _markNotificationRead(ref, notificationId),
                ),
                _NotificationList(
                  notifications: notifications
                      .where((n) => const {'BOOKING', 'JOB', 'JOB_EXECUTION'}
                          .contains(n.type.toUpperCase()))
                      .toList(),
                  onRefresh: () async =>
                      ref.refresh(notificationsProvider.future),
                  onOpen: (item) => _openWorkerNotification(context, ref, item),
                  onDismiss: (notificationId) =>
                      _markNotificationRead(ref, notificationId),
                ),
                _NotificationList(
                  notifications: notifications
                      .where((n) => const {'PAYMENT', 'EARNINGS'}
                          .contains(n.type.toUpperCase()))
                      .toList(),
                  onRefresh: () async =>
                      ref.refresh(notificationsProvider.future),
                  onOpen: (item) => _openWorkerNotification(context, ref, item),
                  onDismiss: (notificationId) =>
                      _markNotificationRead(ref, notificationId),
                ),
                _NotificationList(
                  notifications: notifications
                      .where((n) => const {'SYSTEM', 'INFO'}
                          .contains(n.type.toUpperCase()))
                      .toList(),
                  onRefresh: () async =>
                      ref.refresh(notificationsProvider.future),
                  onOpen: (item) => _openWorkerNotification(context, ref, item),
                  onDismiss: (notificationId) =>
                      _markNotificationRead(ref, notificationId),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => PremiumRetryState(
            title: 'Could not load notifications',
            subtitle: 'Check your connection and try again.',
            icon: Icons.notifications_off_outlined,
            onRetry: () => ref.invalidate(notificationsProvider),
            onRefresh: () async {
              await ref
                  .refresh(notificationsProvider.future)
                  .then<void>((_) {});
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final List<AppNotification> notifications;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String notificationId) onDismiss;
  final ValueChanged<AppNotification> onOpen;

  const _NotificationList({
    required this.notifications,
    required this.onRefresh,
    required this.onDismiss,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            PremiumEmptyState(
              icon: Icons.notifications_off,
              title: 'No notifications',
              subtitle: 'You are all caught up!',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final item = notifications[index];
          return _NotificationCard(
            item: item,
            onTap: () => onOpen(item),
            onMarkRead: item.isRead ? null : () => onDismiss(item.id),
          );
        },
      ),
    );
  }
}

Future<void> _markAllNotificationsRead(
    BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(notificationsRepositoryProvider).markAllAsRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationsUnreadCountProvider);
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not mark notifications as read.')),
    );
  }
}

Future<void> _markNotificationRead(WidgetRef ref, String notificationId) async {
  try {
    await ref.read(notificationsRepositoryProvider).markAsRead(notificationId);
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationsUnreadCountProvider);
  } catch (_) {
    // Best-effort only; the list still refreshes on pull-to-refresh.
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    IconData icon;
    Color color;

    if (item.type == 'BOOKING' || item.type == 'JOB') {
      icon = Icons.work;
      color = cs.primary;
    } else if (item.type == 'PAYMENT' || item.type == 'EARNINGS') {
      icon = Icons.payments;
      color = const Color(0xFF10B981);
    } else {
      icon = Icons.info;
      color = const Color(0xFFF59E0B);
    }

    final isRead = item.isRead;

    return Container(
      color: isRead ? Colors.transparent : cs.primary.withValues(alpha: 0.05),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: tt.titleMedium?.copyWith(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(item.body),
            const SizedBox(height: 4),
            Text(
              _formatDate(item.createdAt),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        trailing: onMarkRead == null
            ? const Icon(Icons.chevron_right_rounded)
            : IconButton(
                tooltip: 'Mark as read',
                onPressed: onMarkRead,
                icon: const Icon(Icons.mark_email_read_outlined),
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

Future<void> _openWorkerNotification(
  BuildContext context,
  WidgetRef ref,
  AppNotification item,
) async {
  if (!item.isRead) {
    await _markNotificationRead(ref, item.id);
  }
  if (!context.mounted) return;

  final bookingId = item.data?['bookingId'];
  if (bookingId is String && bookingId.trim().isNotEmpty) {
    context.push(
      '/job-execution?bookingId=${Uri.encodeComponent(bookingId.trim())}',
    );
    return;
  }

  switch (item.type.toUpperCase()) {
    case 'BOOKING':
    case 'JOB':
    case 'JOB_EXECUTION':
      context.go('/jobs');
      break;
    case 'PAYMENT':
    case 'EARNINGS':
      context.go('/earnings');
      break;
    case 'SYSTEM':
    case 'INFO':
      context.go('/profile');
      break;
  }
}
