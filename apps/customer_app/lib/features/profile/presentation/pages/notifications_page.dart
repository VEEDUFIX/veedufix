import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final Set<String> _openingNotifications = <String>{};
  bool _isMarkingAllRead = false;

  Future<void> _openNotificationOnce(AppNotification notification) async {
    if (!_openingNotifications.add(notification.id)) return;
    setState(() {});
    try {
      await _openNotification(context, ref, notification);
    } finally {
      _openingNotifications.remove(notification.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _markAllReadOnce() async {
    if (_isMarkingAllRead) return;
    setState(() => _isMarkingAllRead = true);
    try {
      await _markAllNotificationsRead(context, ref);
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text(
          'Notifications',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (notifAsync.valueOrNull?.any(
                (notification) => !notification.isRead,
              ) ==
              true)
            TextButton(
              onPressed: _isMarkingAllRead ? null : _markAllReadOnce,
              child: _isMarkingAllRead
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Mark all read'),
            ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => PremiumRetryState(
          icon: Icons.notifications_off_rounded,
          title: 'Could not load notifications',
          subtitle: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(notificationsProvider),
          onRefresh: () async {
            await ref.refresh(notificationsProvider.future).then<void>((_) {});
          },
        ),
        data: (notifications) => notifications.isEmpty
            ? RefreshIndicator(
                onRefresh: () => ref.refresh(notificationsProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.72,
                      child: const Center(
                        child: PremiumEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'All caught up!',
                          subtitle: 'You have no notifications right now.',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(notificationsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final notif = notifications[i];
                    return TapScale(
                      onTap: _openingNotifications.contains(notif.id)
                          ? null
                          : () => _openNotificationOnce(notif),
                      child: PremiumCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _notifColor(
                                    notif.type,
                                    cs,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _notifIcon(notif.type),
                                  color: _notifColor(notif.type, cs),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notif.title,
                                            style: tt.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (!notif.isRead)
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
                                    const SizedBox(height: 4),
                                    Text(
                                      notif.body,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _timeAgo(notif.createdAt),
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  IconData _notifIcon(String type) {
    switch (type.toUpperCase()) {
      case 'BOOKING':
        return Icons.calendar_today_rounded;
      case 'PAYMENT':
        return Icons.payments_rounded;
      case 'PROMO':
        return Icons.local_offer_rounded;
      case 'REFERRAL':
        return Icons.people_rounded;
      case 'SYSTEM':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _notifColor(String type, ColorScheme cs) {
    switch (type.toUpperCase()) {
      case 'BOOKING':
        return cs.primary;
      case 'PAYMENT':
        return const Color(0xFF10B981);
      case 'PROMO':
        return const Color(0xFFF59E0B);
      case 'REFERRAL':
        return const Color(0xFF8B5CF6);
      default:
        return cs.secondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final localDate = dt.toLocal();
    final diff = DateTime.now().difference(localDate);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }
}

Future<void> _openNotification(
  BuildContext context,
  WidgetRef ref,
  AppNotification notification,
) async {
  if (!notification.isRead) {
    await _markNotificationRead(context, ref, notification.id);
  }
  if (!context.mounted) return;

  final bookingId = notification.data?['bookingId'];
  if (bookingId is String && bookingId.trim().isNotEmpty) {
    context.push('/booking/${Uri.encodeComponent(bookingId.trim())}');
    return;
  }

  final route = notification.data?['route'];
  const allowedRoutes = {
    '/app',
    '/bookings',
    '/offers',
    '/wallet',
    '/referral',
    '/support',
    '/profile',
  };
  if (route is String && allowedRoutes.contains(route)) {
    context.push(route);
    return;
  }

  switch (notification.type.toUpperCase()) {
    case 'BOOKING':
    case 'JOB':
    case 'JOB_EXECUTION':
      context.push('/bookings');
      break;
    case 'PAYMENT':
    case 'EARNINGS':
      context.push('/wallet');
      break;
    case 'PROMO':
      context.push('/offers');
      break;
    case 'REFERRAL':
      context.push('/referral');
      break;
  }
}

Future<void> _markAllNotificationsRead(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    await ref.read(apiClientProvider).post('/notifications/mark-all-read');
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationsUnreadCountProvider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read.')),
    );
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not update notifications. Please try again.'),
      ),
    );
  }
}

Future<bool> _markNotificationRead(
  BuildContext context,
  WidgetRef ref,
  String notificationId,
) async {
  if (notificationId.trim().isEmpty) return false;
  try {
    await ref
        .read(apiClientProvider)
        .patch('/notifications/$notificationId/read');
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationsUnreadCountProvider);
    return true;
  } catch (_) {
    if (!context.mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not update notification.')),
    );
    return false;
  }
}
