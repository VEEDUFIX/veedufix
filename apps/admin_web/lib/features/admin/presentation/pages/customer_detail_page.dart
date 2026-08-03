import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AdminCustomerDetailPage extends ConsumerStatefulWidget {
  const AdminCustomerDetailPage({
    super.key,
    required this.customerId,
  });

  final String customerId;

  @override
  ConsumerState<AdminCustomerDetailPage> createState() => _AdminCustomerDetailPageState();
}

class _AdminCustomerDetailPageState extends ConsumerState<AdminCustomerDetailPage> {
  late final Future<_AdminCustomerDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AdminCustomerDetail> _load() async {
    final api = ref.read(apiClientProvider);
    final data = await api.get('/admin/customers/${widget.customerId}');
    return _AdminCustomerDetail.fromJson((data['customer'] as Map<String, dynamic>? ?? const <String, dynamic>{}), data['recentBookings'] as List<dynamic>? ?? const []);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
        title: Text('Customer detail', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_AdminCustomerDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Customer not available',
                subtitle: snapshot.error.toString(),
                actionLabel: 'Try again',
                onAction: _reload,
              ),
            );
          }

          final customer = snapshot.data;
          if (customer == null) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Customer not available',
                subtitle: 'We could not load this customer.',
                actionLabel: 'Try again',
                onAction: _reload,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MarketplaceNetworkAvatar(
                              imageUrl: customer.avatarUrl,
                              radius: 34,
                              fallback: Text(
                                customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : 'C',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Text(
                                    customer.isActive ? 'Active customer' : 'Banned customer',
                                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: customer.isActive ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                customer.isActive ? 'Active' : 'Banned',
                                style: tt.labelMedium?.copyWith(
                                  color: customer.isActive ? const Color(0xFF10B981) : Colors.red,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Bookings',
                                value: customer.totalBookings.toString(),
                                icon: Icons.receipt_long_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                label: 'Spend',
                                value: '₹${customer.totalSpend.toStringAsFixed(0)}',
                                icon: Icons.currency_rupee_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Contact'),
                const SizedBox(height: 10),
                _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(label: 'Phone', value: customer.phone),
                        _DetailRow(label: 'Email', value: customer.email ?? 'Not provided'),
                        _DetailRow(label: 'Joined', value: DateFormat('d MMM y').format(customer.createdAt)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Recent bookings'),
                const SizedBox(height: 10),
                if (customer.recentBookings.isEmpty)
                  const _SurfaceCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No recent bookings found.'),
                    ),
                  )
                else
                  Column(
                    children: customer.recentBookings
                        .map(
                          (booking) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BookingRow(booking: booking),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminCustomerDetail {
  const _AdminCustomerDetail({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.avatarUrl,
    required this.isActive,
    required this.totalBookings,
    required this.totalSpend,
    required this.createdAt,
    required this.recentBookings,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final bool isActive;
  final int totalBookings;
  final double totalSpend;
  final DateTime createdAt;
  final List<_AdminCustomerBooking> recentBookings;

  factory _AdminCustomerDetail.fromJson(Map<String, dynamic> json, List<dynamic> bookingsJson) {
    return _AdminCustomerDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Customer',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      totalSpend: (json['totalSpend'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      recentBookings: bookingsJson
          .whereType<Map<String, dynamic>>()
          .map(_AdminCustomerBooking.fromJson)
          .toList(growable: false),
    );
  }
}

class _AdminCustomerBooking {
  const _AdminCustomerBooking({
    required this.id,
    required this.code,
    required this.status,
    required this.scheduledAt,
    required this.totalAmount,
    required this.workerName,
    required this.serviceName,
    required this.addressLabel,
  });

  final String id;
  final String code;
  final String status;
  final DateTime scheduledAt;
  final double totalAmount;
  final String? workerName;
  final String serviceName;
  final String? addressLabel;

  factory _AdminCustomerBooking.fromJson(Map<String, dynamic> json) {
    return _AdminCustomerBooking(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ?? DateTime.now(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      workerName: json['workerName'] as String?,
      serviceName: json['serviceName'] as String? ?? 'Service',
      addressLabel: json['addressLabel'] as String?,
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});
  final _AdminCustomerBooking booking;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${booking.code}', style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(booking.serviceName, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${booking.status.replaceAll('_', ' ')} • ${DateFormat('d MMM y, h:mm a').format(booking.scheduledAt)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${booking.totalAmount.toStringAsFixed(0)}', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(booking.workerName ?? 'Unassigned', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => PremiumGlassCard(child: child);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(value, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
