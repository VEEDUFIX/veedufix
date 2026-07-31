import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text('Notifications', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () => _markAllNotificationsRead(context, ref),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(
          child: PremiumEmptyState(
            icon: Icons.notifications_off_rounded,
            title: 'Could not load notifications',
            subtitle: 'Pull down to try again.',
          ),
        ),
        data: (notifications) => notifications.isEmpty
            ? const Center(
                child: PremiumEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'All caught up!',
                  subtitle: 'You have no notifications right now.',
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
                      onTap: () => _markNotificationRead(context, ref, notif.id),
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
                                  color: _notifColor(notif.type, cs).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_notifIcon(notif.type), color: _notifColor(notif.type, cs), size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(notif.title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                        ),
                                        if (!notif.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(notif.body, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
                                    const SizedBox(height: 6),
                                    Text(_timeAgo(notif.createdAt), style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
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
      case 'BOOKING': return Icons.calendar_today_rounded;
      case 'PAYMENT': return Icons.payments_rounded;
      case 'PROMO': return Icons.local_offer_rounded;
      case 'REFERRAL': return Icons.people_rounded;
      case 'SYSTEM': return Icons.info_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _notifColor(String type, ColorScheme cs) {
    switch (type.toUpperCase()) {
      case 'BOOKING': return cs.primary;
      case 'PAYMENT': return const Color(0xFF10B981);
      case 'PROMO': return const Color(0xFFF59E0B);
      case 'REFERRAL': return const Color(0xFF8B5CF6);
      default: return cs.secondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

Future<void> _markAllNotificationsRead(BuildContext context, WidgetRef ref) async {
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
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not update notifications: $error')),
    );
  }
}

Future<void> _markNotificationRead(BuildContext context, WidgetRef ref, String notificationId) async {
  try {
    await ref.read(apiClientProvider).patch('/notifications/$notificationId/read');
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationsUnreadCountProvider);
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not update notification.')),
    );
  }
}
