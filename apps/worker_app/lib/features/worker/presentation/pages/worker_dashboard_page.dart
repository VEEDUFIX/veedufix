import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/realtime/realtime_socket_service.dart';

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

    final auth = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are fully booked for today.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stay on top of jobs, keep customers updated, and track earnings in real time.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.74),
                          height: 1.45,
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
          const Row(
            children: [
              Expanded(
                child: PremiumStatCard(
                  label: 'Today',
                  value: '6 jobs',
                  icon: Icons.work_history_rounded,
                  accentColor: Color(0xFF0F766E),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: PremiumStatCard(
                  label: 'Rating',
                  value: '4.9',
                  icon: Icons.star_rounded,
                  accentColor: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const PremiumStatCard(
            label: 'This week earnings',
            value: 'Rs. 8,420',
            icon: Icons.payments_rounded,
            accentColor: Color(0xFF14B8A6),
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
                  auth == null
                      ? 'Sign in to receive live updates.'
                      : 'No live events yet. New notifications and booking changes will appear here.',
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
          const _JobCard(
            title: 'Kitchen sink repair',
            status: 'Accepted',
            time: 'Today, 2:00 PM',
          ),
          const SizedBox(height: 12),
          const _JobCard(
            title: 'AC installation',
            status: 'En route',
            time: 'Today, 4:30 PM',
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
  });

  final String title;
  final String status;
  final String time;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(time),
        trailing: Chip(label: Text(status)),
      ),
    );
  }
}
