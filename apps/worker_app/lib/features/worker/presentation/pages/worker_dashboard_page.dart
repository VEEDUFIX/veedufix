import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/worker_logo.dart';
import '../providers/worker_availability_provider.dart';

class WorkerDashboardPage extends ConsumerStatefulWidget {
  const WorkerDashboardPage({super.key});

  @override
  ConsumerState<WorkerDashboardPage> createState() =>
      _WorkerDashboardPageState();
}

class _WorkerDashboardPageState extends ConsumerState<WorkerDashboardPage> {
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  final List<_LiveUpdateItem> _liveUpdates = <_LiveUpdateItem>[];
  bool _connected = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSocket();
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    ref.read(realtimeServiceProvider).disconnectNotifications();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || _connecting || _notificationSubscription != null) {
      return;
    }

    _connecting = true;
    final service = ref.read(realtimeServiceProvider);
    try {
      await service.connectNotifications();

      _notificationSubscription = service.notificationStream.listen(
        (payload) {
          final title = payload['title'] as String? ??
              payload['bookingCode'] as String? ??
              'Live update';
          final body = payload['body'] as String? ??
              payload['message'] as String? ??
              'Something changed on your account.';
          final channel = payload['channel'] as String? ?? 'live';

          if (!mounted) return;
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
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _connected = false);
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _connected = false);
        },
      );

      if (mounted) setState(() => _connected = true);
    } catch (_) {
      if (mounted) setState(() => _connected = false);
    } finally {
      _connecting = false;
    }
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

  String _firstName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'there';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String _timeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    }
    if (hour < 17) {
      return 'Afternoon';
    }
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (_, next) {
      if (next.valueOrNull == null) {
        _notificationSubscription?.cancel();
        _notificationSubscription = null;
        ref.read(realtimeServiceProvider).disconnectNotifications();
        if (mounted) setState(() => _connected = false);
      } else {
        _connectSocket();
      }
    });

    final isSignedIn = ref.watch(
            authControllerProvider.select((s) => s.valueOrNull?.user.id)) !=
        null;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final statsAsync = ref.watch(workerDashboardStatsProvider);
    final unreadNotifications =
        ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0;
    final displayName = _firstName(session?.user.name);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const WorkerLogo(height: 24),
            const SizedBox(width: 8),
            Text(
              'Dashboard',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        unreadNotifications > 99
                            ? '99+'
                            : '$unreadNotifications',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_timeOfDay()}, $displayName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _AvailabilityToggleCard(),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 16,
                color: _connected
                    ? AbzioTheme.workerPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                _connected
                    ? 'Live updates connected'
                    : 'Waiting for live updates',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _connected
                          ? AbzioTheme.workerPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const PremiumSectionHeader(
            title: 'Today\'s route',
            subtitle: 'Upcoming visits and active jobs in one view.',
          ),
          const SizedBox(height: 12),
          statsAsync.when(
            data: (stats) {
              if (stats.todayJobs.isEmpty) {
                return PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AbzioTheme.workerPrimary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.event_busy_rounded,
                                color: AbzioTheme.workerPrimary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No jobs scheduled today',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stay available and keep notifications on. New jobs will appear here as soon as they are assigned.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          height: 1.45,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: () => context.go('/jobs'),
                              icon: const Icon(Icons.work_history_rounded,
                                  size: 18),
                              label: const Text('Open jobs'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/schedule'),
                              icon: const Icon(Icons.calendar_month_rounded,
                                  size: 18),
                              label: const Text('Check schedule'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: stats.todayJobs.map((job) {
                  final route = job.bookingId.isNotEmpty
                      ? '/job-execution?bookingId=${job.bookingId}'
                      : '/jobs';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _JobCard(
                      title: job.serviceName,
                      status: job.status,
                      time: DateFormat('h:mm a').format(job.scheduledAt),
                      onTap: () => context.push(route),
                      job: job,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load today\'s route',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We could not fetch your route just now. Try refreshing the dashboard.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.go('/jobs'),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Open jobs'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
                        accentColor: AbzioTheme.workerPrimary,
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
                  accentColor: AbzioTheme.workerAccent,
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load today\'s stats',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please try again. Your jobs and live updates are still available below.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.refresh(workerDashboardStatsProvider.future),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const PremiumSectionHeader(
            title: 'Recent updates',
            subtitle: 'Job, customer and payout changes.',
          ),
          const SizedBox(height: 12),
          if (_liveUpdates.isEmpty)
            PremiumGlassCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSignedIn
                                ? 'You\'re all caught up'
                                : 'Sign in for live updates',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isSignedIn
                                ? 'New booking changes will appear here.'
                                : 'Booking changes will appear here after sign-in.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
          const SizedBox(height: 24),
          // Quick actions.
          const PremiumSectionHeader(
            title: 'Quick actions',
            subtitle: 'Shortcuts for the workday.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickAction(
                icon: Icons.calendar_month_rounded,
                label: 'Schedule',
                color: AbzioTheme.workerPrimary,
                onTap: () => context.go('/schedule'),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.payments_rounded,
                label: 'Earnings',
                color: AbzioTheme.workerPrimary,
                onTap: () => context.go('/earnings'),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.support_agent_rounded,
                label: 'Support',
                color: AbzioTheme.workerPrimary,
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
    final accent =
        isTracking ? AbzioTheme.workerPrimary : AbzioTheme.workerAccent;

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
                isTracking
                    ? Icons.route_rounded
                    : Icons.notifications_active_rounded,
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relativeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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

  Future<void> _openNavigation(BuildContext context) async {
    void showNavigationError() {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation.')),
      );
    }

    try {
      final lat = job.destinationLatitude;
      final lng = job.destinationLongitude;
      final query = [
        job.addressLabel?.trim(),
        job.cityName?.trim(),
        job.destinationQuery?.trim(),
      ]
          .where((part) => part != null && part.isNotEmpty)
          .cast<String>()
          .join(', ');
      if ((lat == null || lng == null) && query.isEmpty) {
        showNavigationError();
        return;
      }

      final uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': 'Current+Location',
        'destination': lat != null && lng != null ? '$lat,$lng' : query,
        'travelmode': 'driving',
        'dir_action': 'navigate',
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        showNavigationError();
      }
    } catch (_) {
      showNavigationError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEnRoute = status == 'En route';
    final accent = isEnRoute ? const Color(0xFF14B8A6) : cs.primary;

    return PremiumGlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AbzioTheme.cardRadius),
                      ),
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Navigate',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openNavigation(context),
                    icon: Icon(Icons.navigation_rounded, color: accent),
                  ),
                ],
              ),
            ],
          ),
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
    final hasError = toggleState.hasError;
    final isOnline = toggleState.valueOrNull ?? false;
    final isLoading = toggleState.isLoading;

    return _OnlineToggle(
      isOnline: isOnline,
      isLoading: isLoading,
      hasError: hasError,
      onRetry: hasError
          ? () => ref.read(availabilityToggleProvider.notifier).refresh()
          : null,
      onChanged: isLoading || hasError
          ? null
          : (value) async {
              try {
                await ref
                    .read(availabilityToggleProvider.notifier)
                    .toggle(value);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                      content: Text(
                          'Could not update availability. Please try again.')));
              }
            },
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  const _OnlineToggle(
      {required this.isOnline,
      required this.onChanged,
      this.isLoading = false,
      this.hasError = false,
      this.onRetry});
  final bool isOnline;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = hasError
        ? cs.onSurfaceVariant
        : isOnline
            ? const Color(0xFF10B981)
            : cs.error;

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
                  hasError
                      ? 'Availability unavailable'
                      : isOnline
                          ? 'You are Online'
                          : 'You are Offline',
                  style: tt.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  hasError
                      ? 'Check your connection and try again'
                      : isOnline
                          ? 'Accepting new job requests'
                          : 'Not receiving any jobs',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (hasError)
            IconButton(
              tooltip: 'Retry availability',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            )
          else
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
