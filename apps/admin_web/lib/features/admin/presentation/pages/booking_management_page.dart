import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

// ─── Entities ─────────────────────────────────────────────────────────────────

class AdminBooking {
  const AdminBooking({
    required this.id,
    required this.code,
    required this.status,
    required this.paymentStatus,
    required this.paymentRecoveryLabel,
    required this.customerName,
    required this.serviceName,
    required this.scheduledAt,
    required this.totalAmount,
    this.workerName,
    this.addressLabel,
  });

  final String id;
  final String code;
  final String status;
  final String paymentStatus;
  final String paymentRecoveryLabel;
  final String customerName;
  final String serviceName;
  final DateTime scheduledAt;
  final double totalAmount;
  final String? workerName;
  final String? addressLabel;

  factory AdminBooking.fromJson(Map<String, dynamic> json) => AdminBooking(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        paymentStatus: json['paymentStatus'] as String? ?? 'PENDING',
        paymentRecoveryLabel: json['paymentRecoveryLabel'] as String? ?? 'Pending',
        customerName: json['customerName'] as String? ?? 'Customer',
        serviceName: json['serviceName'] as String? ?? 'Service',
        scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ?? DateTime.now(),
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        workerName: json['workerName'] as String?,
        addressLabel: json['addressLabel'] as String?,
      );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final adminBookingsProvider = FutureProvider.autoDispose
    .family<List<AdminBooking>, _BookingFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get(
    '/admin/bookings',
    queryParameters: {
      if (filter.status.isNotEmpty) 'status': filter.status,
      if (filter.search.isNotEmpty) 'search': filter.search,
      if (filter.customQuoteRequested) 'customQuoteRequested': 'true',
    },
  );
  return (data['bookings'] as List<dynamic>? ?? [])
      .map((b) => AdminBooking.fromJson(b as Map<String, dynamic>))
      .toList();
});

class _BookingFilter {
  const _BookingFilter({this.status = '', this.search = '', this.customQuoteRequested = false});
  final String status;
  final String search;
  final bool customQuoteRequested;

  @override
  bool operator ==(Object other) =>
      other is _BookingFilter && other.status == status && other.search == search && other.customQuoteRequested == customQuoteRequested;

  @override
  int get hashCode => Object.hash(status, search, customQuoteRequested);
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class BookingManagementPage extends ConsumerStatefulWidget {
  const BookingManagementPage({super.key, this.initialSearch = ''});

  final String initialSearch;

  @override
  ConsumerState<BookingManagementPage> createState() => _BookingManagementPageState();
}

class _BookingManagementPageState extends ConsumerState<BookingManagementPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _search = '';
  bool _customQuoteRequested = false;
  late TabController _tabController;

  static const _tabs = [
    ('All', ''),
    ('Pending', 'PENDING'),
    ('Active', 'IN_PROGRESS'),
    ('Completed', 'COMPLETED'),
    ('Cancelled', 'CANCELLED'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    if (widget.initialSearch.isNotEmpty) {
      _searchController.text = widget.initialSearch;
      _search = widget.initialSearch;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentStatus => _tabs[_tabController.index].$2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filter = _BookingFilter(status: _currentStatus, search: _search, customQuoteRequested: _customQuoteRequested);
    final bookingsAsync = ref.watch(adminBookingsProvider(filter));

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
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text('Bookings', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
        ),
      ),
      body: Column(
        children: [
          // ── Search ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by booking ID, code, customer, phone, worker, or service…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Needs Quote'),
                selected: _customQuoteRequested,
                onSelected: (val) => setState(() => _customQuoteRequested = val),
                selectedColor: Colors.orange.withValues(alpha: 0.2),
                checkmarkColor: Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── List ────────────────────────────────────────────────────
          Expanded(
            child: bookingsAsync.when(
              loading: () => ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const _BookingSkeletonCard(),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: PremiumEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load bookings',
                    subtitle: 'The bookings queue is unavailable right now. Please retry.',
                    actionLabel: 'Retry',
                    onAction: () => ref.refresh(adminBookingsProvider(filter).future),
                  ),
                ),
              ),
              data: (bookings) {
                if (bookings.isEmpty) {
                  return const PremiumEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No bookings found',
                    subtitle: 'Try a different filter.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(adminBookingsProvider(filter).future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _AdminBookingCard(booking: bookings[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSkeletonCard extends StatelessWidget {
  const _BookingSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumGlassCard(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerWidget(width: 48, height: 48, radius: 14),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerWidget(width: 180, height: 16, radius: 8),
                      SizedBox(height: 8),
                      ShimmerWidget(width: 120, height: 12, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ShimmerWidget(width: double.infinity, height: 12, radius: 6),
            SizedBox(height: 8),
            ShimmerWidget(width: 160, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }
}

// ─── Booking card ─────────────────────────────────────────────────────────────

class _AdminBookingCard extends StatelessWidget {
  const _AdminBookingCard({required this.booking});
  final AdminBooking booking;

  Color get _statusColor => switch (booking.status) {
        'COMPLETED' => const Color(0xFF10B981),
        'CANCELLED' || 'REFUNDED' => const Color(0xFFEF4444),
        'IN_PROGRESS' || 'ARRIVED' => const Color(0xFF6366F1),
        'EN_ROUTE' => const Color(0xFF14B8A6),
        _ => const Color(0xFFF59E0B),
      };

  String get _statusLabel => switch (booking.status) {
        'COMPLETED' => 'Completed',
        'CANCELLED' => 'Cancelled',
        'REFUNDED' => 'Refunded',
        'IN_PROGRESS' => 'In Progress',
        'ARRIVED' => 'Arrived',
        'EN_ROUTE' => 'En Route',
        'WORKER_ASSIGNED' => 'Assigned',
        'ACCEPTED' => 'Accepted',
        _ => 'Pending',
      };

  Color get _paymentColor => switch (booking.paymentRecoveryLabel) {
        'Reconciled' => const Color(0xFF0EA5E9),
        'Captured' => const Color(0xFF10B981),
        'Failed' => const Color(0xFFEF4444),
        _ => const Color(0xFFF59E0B),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return TapScale(
      onTap: () => context.go('/admin-bookings/${booking.id}'),
      child: PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${booking.code}',
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TapScale(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: booking.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Booking code copied')),
                              );
                            },
                            child: Icon(Icons.copy_rounded, size: 14, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(booking.serviceName,
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _statusLabel,
                    style: tt.labelSmall?.copyWith(
                      color: _statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Info rows
            Row(
              children: [
                _InfoChip(icon: Icons.person_rounded, label: booking.customerName),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.currency_rupee_rounded,
                  label: '₹${booking.totalAmount.toStringAsFixed(0)}',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: booking.id));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Booking ID copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy ID'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: booking.code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Booking code copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.tag_rounded, size: 16),
                  label: const Text('Copy code'),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/audit-logs?search=${Uri.encodeComponent(booking.id)}'),
                  icon: const Icon(Icons.manage_search_rounded, size: 16),
                  label: const Text('Audit'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _paymentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payments_rounded, size: 14, color: _paymentColor),
                      const SizedBox(width: 5),
                      Text(
                        'Payment: ${booking.paymentRecoveryLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _paymentColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: booking.paymentStatus == 'CAPTURED'
                      ? Icons.verified_rounded
                      : Icons.hourglass_bottom_rounded,
                  label: booking.paymentStatus.replaceAll('_', ' '),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: DateFormat('d MMM y, h:mm a').format(booking.scheduledAt),
                ),
              ],
            ),
            if (booking.workerName != null) ...[
              const SizedBox(height: 6),
              _InfoChip(icon: Icons.engineering_rounded, label: booking.workerName!),
            ],
            if (booking.addressLabel != null) ...[
              const SizedBox(height: 6),
              _InfoChip(icon: Icons.location_on_rounded, label: booking.addressLabel!),
            ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
