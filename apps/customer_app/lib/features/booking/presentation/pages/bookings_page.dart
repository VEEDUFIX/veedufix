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
                          onPressed: () {},
                          icon: const Icon(Icons.receipt_long_rounded),
                        ),
                      ),
                    ],
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
                PremiumEmptyState(
                  icon: status == 'upcoming' 
                      ? Icons.event_available_rounded 
                      : status == 'completed' 
                          ? Icons.task_alt_rounded 
                          : Icons.event_busy_rounded,
                  title: status == 'upcoming' 
                      ? 'No upcoming jobs' 
                      : status == 'completed' 
                          ? 'Nothing completed yet' 
                          : 'No cancelled bookings',
                  subtitle: status == 'upcoming'
                      ? 'Book a service and it will appear here.'
                      : status == 'completed'
                          ? 'Completed jobs will appear here with invoice access and ratings.'
                          : 'If a booking is cancelled, the reason and refund status will be shown here.',
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
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Text('Error: $error')),
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

class _BookingCard extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
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
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    ),
                    child: Icon(Icons.home_repair_service_rounded, color: statusColor),
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
            ],
          ),
        ),
      ),
    );
  }
}
