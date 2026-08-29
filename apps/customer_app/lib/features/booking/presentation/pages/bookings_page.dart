import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final upcomingBookings = ref.watch(customerBookingsProvider('upcoming')).valueOrNull ?? const <CustomerBooking>[];
    final completedBookings = ref.watch(customerBookingsProvider('completed')).valueOrNull ?? const <CustomerBooking>[];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bookings',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage active services, track progress, and review past jobs.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                          boxShadow: AbzioTheme.eliteShadow,
                        ),
                        child: IconButton(
                          tooltip: 'Open latest booking or invoice',
                          onPressed: () {
                            if (completedBookings.isNotEmpty) {
                              context.push('/invoice/${completedBookings.first.id}');
                              return;
                            }
                            if (upcomingBookings.isNotEmpty) {
                              context.push('/booking/${upcomingBookings.first.id}');
                              return;
                            }
                            context.push('/search');
                          },
                          icon: const Icon(Icons.receipt_long_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _BookingsOverviewCard(
                    upcomingCount: upcomingBookings.length,
                    completedCount: completedBookings.length,
                    onBookNow: () => context.push('/search'),
                    onOpenLatest: () {
                      if (completedBookings.isNotEmpty) {
                        context.push('/invoice/${completedBookings.first.id}');
                        return;
                      }
                      if (upcomingBookings.isNotEmpty) {
                        context.push('/booking/${upcomingBookings.first.id}');
                        return;
                      }
                      context.push('/search');
                    },
                  ),
                  const SizedBox(height: 18),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Completed'),
                      Tab(text: 'Cancelled'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _BookingsTab(status: 'upcoming'),
                  _BookingsTab(status: 'completed'),
                  _BookingsTab(status: 'cancelled'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsOverviewCard extends StatelessWidget {
  const _BookingsOverviewCard({
    required this.upcomingCount,
    required this.completedCount,
    required this.onBookNow,
    required this.onOpenLatest,
  });

  final int upcomingCount;
  final int completedCount;
  final VoidCallback onBookNow;
  final VoidCallback onOpenLatest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your booking hub',
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep track of active work, revisit finished services, or book the next job without digging through menus.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
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
                _BookingSummaryPill(
                  label: 'Upcoming',
                  value: '$upcomingCount',
                  icon: Icons.event_available_rounded,
                ),
                _BookingSummaryPill(
                  label: 'Completed',
                  value: '$completedCount',
                  icon: Icons.task_alt_rounded,
                ),
                const _BookingSummaryPill(
                  label: 'Fast access',
                  value: 'Invoices',
                  icon: Icons.receipt_long_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onBookNow,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Book now'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenLatest,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open latest'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingSummaryPill extends StatelessWidget {
  const _BookingSummaryPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab({required this.status});
  
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(customerBookingsProvider(status));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(customerBookingsProvider(status).future),
      child: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            status == 'upcoming'
                                ? Icons.event_available_rounded
                                : status == 'completed'
                                    ? Icons.task_alt_rounded
                                    : Icons.event_busy_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status == 'upcoming'
                                    ? 'No upcoming jobs'
                                    : status == 'completed'
                                        ? 'Nothing completed yet'
                                        : 'No cancelled bookings',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                status == 'upcoming'
                                    ? 'Book a service and it will appear here.'
                                    : status == 'completed'
                                        ? 'Completed jobs will show here with invoice access and ratings.'
                                        : 'If a booking is cancelled, the reason and refund status will appear here.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => context.push('/search'),
                                    icon: const Icon(Icons.search_rounded, size: 18),
                                    label: const Text('Book now'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => ref.refresh(customerBookingsProvider(status).future),
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text('Refresh view'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _BookingCard(booking: bookings[index], statusType: status);
            },
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => const _SkeletonCard(),
        ),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            PremiumGlassCard(
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
                            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.cloud_off_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Could not load bookings',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'We could not fetch your bookings right now. Try again in a moment or pull to refresh.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => ref.refresh(customerBookingsProvider(status).future),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumGlassCard(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerPlaceholder(width: 48, height: 48, borderRadius: 12),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerPlaceholder(width: 120, height: 16, borderRadius: 4),
                      SizedBox(height: 8),
                      ShimmerPlaceholder(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                ShimmerPlaceholder(width: 60, height: 24, borderRadius: 12),
              ],
            ),
            SizedBox(height: 16),
            ShimmerPlaceholder(width: double.infinity, height: 1, borderRadius: 0),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerPlaceholder(width: 100, height: 14, borderRadius: 4),
                ShimmerPlaceholder(width: 60, height: 14, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking, required this.statusType});

  final CustomerBooking booking;
  final String statusType;

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'ASSIGNED':
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.red;
      case 'PENDING':
      default:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[date.month - 1];
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return '${date.day} $month ${date.year}, $hour:$min $amPm';
  }

  bool get _canBookAgain {
    final status = booking.status.toUpperCase();
    return status != 'PENDING' &&
        status != 'ASSIGNED' &&
        status != 'IN_PROGRESS';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _getStatusColor(booking.status);

    return TapScale(
      onTap: () => context.push('/booking/${booking.id}'),
      child: PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                        ),
                        child: Icon(Icons.home_repair_service_rounded, color: statusColor),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.serviceName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(booking.scheduledAt.toLocal()),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      booking.status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.addressLabel ?? booking.cityName ?? 'Address not specified',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${booking.totalAmount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                  ),
                ],
              ),
              if (booking.worker != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      MarketplaceNetworkAvatar(
                        imageUrl: booking.worker!.avatarUrl,
                        radius: 16,
                        backgroundColor: colorScheme.primaryContainer,
                        fallback: Icon(Icons.person_rounded, size: 18, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          booking.worker!.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                          const SizedBox(width: 4),
                          Text(
                            booking.worker!.rating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_canBookAgain) ...[
                const SizedBox(height: 12),
                TapScale(
                  onTap: () => _openRebookBooking(context),
                  child: Semantics(
                    button: true,
                    label: 'Book again for ${booking.serviceName}',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Book again',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openRebookBooking(BuildContext context) {
    final serviceSlug = booking.serviceSlug;
    if (serviceSlug != null && serviceSlug.isNotEmpty) {
      context.push('/service?id=${Uri.encodeComponent(serviceSlug)}');
      return;
    }

    context.push('/search?q=${Uri.encodeComponent(booking.serviceName)}');
  }
}
