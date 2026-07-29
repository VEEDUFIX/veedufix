import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

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
            TextButton(
              onPressed: () {
                // Not supported by API yet
              },
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
                  onRefresh: () async => ref.refresh(notificationsProvider.future),
                  onDismiss: () => ref.invalidate(notificationsProvider),
                ),
                _NotificationList(
                  notifications: notifications.where((n) => n.type == 'BOOKING' || n.type == 'JOB').toList(),
                  onRefresh: () async => ref.refresh(notificationsProvider.future),
                  onDismiss: () => ref.invalidate(notificationsProvider),
                ),
                _NotificationList(
                  notifications: notifications.where((n) => n.type == 'PAYMENT' || n.type == 'EARNINGS').toList(),
                  onRefresh: () async => ref.refresh(notificationsProvider.future),
                  onDismiss: () => ref.invalidate(notificationsProvider),
                ),
                _NotificationList(
                  notifications: notifications.where((n) => n.type == 'SYSTEM' || n.type == 'INFO').toList(),
                  onRefresh: () async => ref.refresh(notificationsProvider.future),
                  onDismiss: () => ref.invalidate(notificationsProvider),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading notifications', style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => ref.refresh(notificationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final List<AppNotification> notifications;
  final Future<void> Function() onRefresh;
  final VoidCallback onDismiss;

  const _NotificationList({
    required this.notifications,
    required this.onRefresh,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const PremiumEmptyState(
        icon: Icons.notifications_off,
        title: 'No notifications',
        subtitle: 'You are all caught up!',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final item = notifications[index];
          return Dismissible(
            key: Key(item.id),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              // Usually calls API here, but optimistic UI as requested
              onDismiss();
            },
            child: _NotificationCard(item: item),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;

  const _NotificationCard({required this.item});

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
