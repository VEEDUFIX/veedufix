import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/widgets/worker_logo.dart';
import '../../../../core/realtime/realtime_socket_service.dart';
import '../providers/worker_availability_provider.dart';

class WorkerDashboardPage extends ConsumerStatefulWidget {
  const WorkerDashboardPage({super.key});

  @override
  ConsumerState<WorkerDashboardPage> createState() => _WorkerDashboardPageState();
}

class _WorkerDashboardPageState extends ConsumerState<WorkerDashboardPage> {
  WebSocketChannel? _notificationChannel;
  StreamSubscription? _notificationSubscription;
  final List<_LiveUpdateItem> _liveUpdates = <_LiveUpdateItem>[];
  String? _activeUserId;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSocket();
    });
  }

  @override
  void dispose() {
    _disposeSocket();
    super.dispose();
  }

  void _disposeSocket() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _notificationChannel?.sink.close();
    _notificationChannel = null;
    _activeUserId = null;
    _connected = false;
  }

  void _syncSocket() {
    final session = ref.read(authControllerProvider).valueOrNull;
    final userId = session?.user.id;

    if (userId == _activeUserId) {
      return;
    }

    _disposeSocket();

    if (session == null) {
      return;
    }

    final environment = ref.read(environmentProvider);
    _notificationChannel = connectNotificationSocket(
      apiBaseUrl: environment.apiBaseUrl,
      token: session.accessToken,
    );
    _activeUserId = userId;

    _notificationSubscription = _notificationChannel!.stream.listen(
      (message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          final type = decoded['type'] as String?;
          final payload = decoded['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};

          if (type == 'connected') {
            if (!mounted) {
              return;
            }
            setState(() {
              _connected = true;
            });
            return;
          }

          if (type == 'notification.event' || type == 'tracking.event') {
            final title = payload['title'] as String? ??
                payload['bookingCode'] as String? ??
                'Live update';
            final body = payload['body'] as String? ??
                payload['message'] as String? ??
                'Something changed on your account.';
            final channel = decoded['channel'] as String? ?? 'live';

            if (!mounted) {
              return;
            }
            setState(() {
              _connected = true;
              _liveUpdates.insert(
                0,
                _LiveUpdateItem(
                  channel: channel,
                  title: title,
                  body: body,
                  timestamp: DateTime.now(),
                ),
              );
              if (_liveUpdates.length > 5) {
                _liveUpdates.removeRange(5, _liveUpdates.length);
              }
            });
          }
        } catch (_) {
          // Ignore malformed server messages.
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _connected = false;
        });
        _disposeSocket();
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _connected = false;
        });
      },
    );
  }

  String _relativeLabel(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (_, next) {
      if (next.hasValue || next.hasError || !next.isLoading) {
        _syncSocket();
      }
    });

    final isSignedIn = ref.watch(authControllerProvider.select((s) => s.valueOrNull?.user.id)) != null;
    final statsAsync = ref.watch(workerDashboardStatsProvider);
    final unreadNotifications = ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const WorkerLogo(height: 24),
            const SizedBox(width: 8),
            Text(
              'Dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (unreadNotifications > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // ── Online/Offline Toggle ────────────────────────────────────
          const _AvailabilityToggleCard(),
          const SizedBox(height: 16),
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  statsAsync.when(
                    data: (stats) {
                      final headline = stats.todayJobs.isEmpty
                          ? 'No jobs scheduled for today.'
                          : 'You have ${stats.todayJobs.length} jobs scheduled today.';
                      final subtitle = stats.todayJobs.isEmpty
                          ? 'Stay available to receive new bookings and keep live updates flowing.'
                          : 'Stay on top of jobs, keep customers updated, and track earnings in real time.';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headline,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.74),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      );
                    },
                    loading: () => Text(
                      'Loading today\'s schedule...',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    error: (_, __) => Text(
                      'Your day at a glance.',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        _connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        size: 18,
                        color: _connected ? const Color(0xFF0F766E) : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _connected ? 'Live updates connected' : 'Waiting for live updates',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _connected
                                  ? const Color(0xFF0F766E)
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          statsAsync.when(
            data: (stats) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PremiumStatCard(
                        label: 'Today',
                        value: '${stats.todayJobs.length} jobs today',
                        icon: Icons.work_history_rounded,
                        accentColor: const Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PremiumStatCard(
                        label: 'Rating',
                        value: stats.averageRating.toStringAsFixed(1),
                        icon: Icons.star_rounded,
                        accentColor: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PremiumStatCard(
                  label: 'This month earnings',
                  value: '₹${stats.monthlyEarnings.toStringAsFixed(0)}',
                  icon: Icons.payments_rounded,
                  accentColor: const Color(0xFF14B8A6),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading stats: $e')),
          ),
          const SizedBox(height: 20),
          const PremiumSectionHeader(
            title: 'Live updates',
            subtitle: 'Realtime notifications from the marketplace and booking activity.',
          ),
          const SizedBox(height: 12),
          if (_liveUpdates.isEmpty)
            PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  isSignedIn
                      ? 'No live events yet. New notifications and booking changes will appear here.'
                      : 'Sign in to receive live updates.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ..._liveUpdates.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LiveUpdateCard(
                  item: item,
                  relativeLabel: _relativeLabel(item.timestamp),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const PremiumSectionHeader(
            title: 'Today\'s route',
            subtitle: 'Upcoming visits and active jobs in one view.',
          ),
          const SizedBox(height: 12),
          statsAsync.when(
            data: (stats) {
              if (stats.todayJobs.isEmpty) {
                return const Text('No jobs scheduled today', style: TextStyle(color: Colors.grey));
              }
              return Column(
                children: stats.todayJobs.map((job) {
                  final route = job.bookingId.isNotEmpty ? '/job-execution?bookingId=${job.bookingId}' : '/jobs';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _JobCard(
                      title: job.serviceName,
                      status: job.status,
                      time: '${DateFormat('h:mm a').format(job.scheduledAt)} • ${job.addressLabel ?? 'No address'}',
                      onTap: () => context.push(route),
                      job: job,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 24),
          // ── Quick Actions ────────────────────────────────────────────
          const PremiumSectionHeader(
            title: 'Quick actions',
            subtitle: 'Common tasks at your fingertips.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickAction(
                icon: Icons.calendar_month_rounded,
                label: 'Schedule',
                color: const Color(0xFF6366F1),
                onTap: () => context.go('/schedule'),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.payments_rounded,
                label: 'Earnings',
                color: const Color(0xFF14B8A6),
                onTap: () => context.go('/earnings'),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Wallet',
                color: const Color(0xFF10B981),
                onTap: () => context.push('/wallet'),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.star_rounded,
                label: 'Reviews',
                color: const Color(0xFFF59E0B),
                onTap: () => context.push('/reviews'),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.support_agent_rounded,
                label: 'Support',
                color: const Color(0xFF3B82F6),
                onTap: () => context.push(
                  '/support?autoFocusForm=true&category=app&subject=${Uri.encodeComponent('Worker app support')}&message=${Uri.encodeComponent('I need help with my worker app account, jobs, or payouts.')}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveUpdateItem {
  const _LiveUpdateItem({
    required this.channel,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  final String channel;
  final String title;
  final String body;
  final DateTime timestamp;
}

class _LiveUpdateCard extends StatelessWidget {
  const _LiveUpdateCard({
    required this.item,
    required this.relativeLabel,
  });

  final _LiveUpdateItem item;
  final String relativeLabel;

  @override
  Widget build(BuildContext context) {
    final isTracking = item.channel == 'tracking';
    final accent = isTracking ? const Color(0xFF0F766E) : const Color(0xFF14B8A6);

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isTracking ? Icons.route_rounded : Icons.notifications_active_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relativeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.title,
    required this.status,
    required this.time,
    required this.job,
    this.onTap,
  });

  final String title;
  final String status;
  final String time;
  final WorkerJob job;
  final VoidCallback? onTap;

  Future<void> _openNavigation() async {
    final lat = job.destinationLatitude;
    final lng = job.destinationLongitude;
    if (lat != null && lng != null) {
      final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final query = [
      job.addressLabel?.trim(),
      job.cityName?.trim(),
      job.destinationQuery?.trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>().join(', ');
    if (query.isEmpty) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(query)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEnRoute = status == 'En route';
    final accent = isEnRoute ? const Color(0xFF14B8A6) : cs.primary;

    return PremiumGlassCard(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(time),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Navigate',
              onPressed: _openNavigation,
              icon: Icon(Icons.navigation_rounded, color: accent),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityToggleCard extends ConsumerWidget {
  const _AvailabilityToggleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toggleState = ref.watch(availabilityToggleProvider);
    final isOnline = toggleState.valueOrNull ?? true;
    final isLoading = toggleState.isLoading;

    return _OnlineToggle(
      isOnline: isOnline,
      isLoading: isLoading,
      onChanged: (v) => ref.read(availabilityToggleProvider.notifier).toggle(v),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  const _OnlineToggle({required this.isOnline, required this.onChanged, this.isLoading = false});
  final bool isOnline;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = isOnline ? const Color(0xFF10B981) : cs.error;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'You are Online' : 'You are Offline',
                  style: tt.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isOnline ? 'Accepting new job requests' : 'Not receiving any jobs',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isOnline,
            onChanged: onChanged,
            activeTrackColor: accent,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
