import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AdminBookingDetailPage extends ConsumerStatefulWidget {
  const AdminBookingDetailPage({
    super.key,
    required this.bookingId,
  });

  final String bookingId;

  @override
  ConsumerState<AdminBookingDetailPage> createState() => _AdminBookingDetailPageState();
}

class _AdminBookingDetailPageState extends ConsumerState<AdminBookingDetailPage> {
  late final Future<_AdminBookingDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AdminBookingDetail> _load() async {
    final api = ref.read(apiClientProvider);
    final data = await api.get('/admin/bookings/${widget.bookingId}');
    return _AdminBookingDetail.fromJson((data['booking'] as Map<String, dynamic>? ?? const <String, dynamic>{}));
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
        title: Text('Booking detail', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_AdminBookingDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Booking not available',
                subtitle: snapshot.error.toString(),
                actionLabel: 'Try again',
                onAction: _reload,
              ),
            );
          }

          final booking = snapshot.data;
          if (booking == null) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Booking not available',
                subtitle: 'We could not load this booking.',
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#${booking.code}',
                                    style: tt.labelMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking.serviceName,
                                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(booking.status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                booking.status.replaceAll('_', ' '),
                                style: tt.labelMedium?.copyWith(
                                  color: _statusColor(booking.status),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _Chip(label: booking.paymentRecoveryLabel),
                            _Chip(label: booking.paymentStatus),
                            _Chip(label: DateFormat('d MMM y, h:mm a').format(booking.scheduledAt)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Total',
                                value: '₹${booking.totalAmount.toStringAsFixed(0)}',
                                icon: Icons.currency_rupee_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                label: 'Payments',
                                value: '${booking.payments.length}',
                                icon: Icons.payments_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (booking.customQuoteStatus != null) ...[
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Custom Quote'),
                  const SizedBox(height: 10),
                  _CustomQuoteCard(
                    bookingId: booking.id,
                    status: booking.customQuoteStatus!,
                    amount: booking.customQuoteAmount,
                    notes: booking.customQuoteNotes,
                    itemized: booking.customQuoteItemized,
                    onReload: _reload,
                  ),
                ],
                const SizedBox(height: 16),
                const _SectionTitle(title: 'People'),
                const SizedBox(height: 10),
                _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Customer',
                          value: booking.customer.name,
                          onTap: booking.customer.id.isEmpty ? null : () => context.push('/customers/${booking.customer.id}'),
                        ),
                        _DetailRow(label: 'Phone', value: booking.customer.phone ?? 'Not provided'),
                        _DetailRow(
                          label: 'Worker',
                          value: booking.worker?.fullName ?? 'Unassigned',
                          onTap: booking.worker == null || booking.worker!.id.isEmpty
                              ? null
                              : () => context.push('/workers/${booking.worker!.id}'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Location'),
                const SizedBox(height: 10),
                _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(label: 'Address', value: booking.address?.label ?? 'Not provided'),
                        _DetailRow(label: 'Line 1', value: booking.address?.line1 ?? 'Not provided'),
                        _DetailRow(label: 'City', value: booking.address?.cityName ?? 'Not provided'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Payments'),
                const SizedBox(height: 10),
                _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: booking.payments.isEmpty
                        ? const Text('No payment records found.')
                        : Column(
                            children: booking.payments
                                .map(
                                  (payment) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _PaymentRow(payment: payment),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Service Items'),
                const SizedBox(height: 10),
                _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: booking.services
                          .map(
                            (service) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DetailRow(
                                label: service.serviceId ?? service.serviceName,
                                value: service.serviceName,
                                onTap: service.serviceId == null
                                    ? null
                                    : () => context.push('/catalog/services/${service.serviceId}'),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Timeline'),
                const SizedBox(height: 10),
                if (booking.timeline.isEmpty)
                  const _SurfaceCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No timeline events yet.'),
                    ),
                  )
                else
                  _SurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: booking.timeline
                            .map(
                              (event) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TimelineEventRow(event: event),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminBookingDetail {
  const _AdminBookingDetail({
    required this.id,
    required this.code,
    required this.status,
    required this.paymentStatus,
    required this.paymentRecoveryLabel,
    required this.customer,
    required this.worker,
    required this.serviceName,
    required this.scheduledAt,
    required this.totalAmount,
    required this.payments,
    required this.services,
    required this.timeline,
    required this.address,
    this.customQuoteStatus,
    this.customQuoteAmount,
    this.customQuoteNotes,
    this.customQuoteItemized,
  });

  final String id;
  final String code;
  final String status;
  final String paymentStatus;
  final String paymentRecoveryLabel;
  final _AdminBookingCustomer customer;
  final _AdminBookingWorker? worker;
  final String serviceName;
  final DateTime scheduledAt;
  final double totalAmount;
  final List<_AdminBookingPayment> payments;
  final List<_AdminBookingService> services;
  final List<_AdminBookingTimelineEvent> timeline;
  final _AdminBookingAddress? address;
  final String? customQuoteStatus;
  final double? customQuoteAmount;
  final String? customQuoteNotes;
  final List<dynamic>? customQuoteItemized;

  factory _AdminBookingDetail.fromJson(Map<String, dynamic> json) {
    return _AdminBookingDetail(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      paymentStatus: json['paymentStatus'] as String? ?? 'PENDING',
      paymentRecoveryLabel: json['paymentRecoveryLabel'] as String? ?? 'Pending',
      customer: _AdminBookingCustomer.fromJson(json['customer'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      worker: json['worker'] is Map<String, dynamic>
          ? _AdminBookingWorker.fromJson(json['worker'] as Map<String, dynamic>)
          : null,
      serviceName: json['serviceName'] as String? ?? 'Service',
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ?? DateTime.now(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      payments: (json['payments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminBookingPayment.fromJson)
          .toList(growable: false),
      services: (json['services'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminBookingService.fromJson)
          .toList(growable: false),
      timeline: (json['timeline'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminBookingTimelineEvent.fromJson)
          .toList(growable: false),
      address: json['address'] is Map<String, dynamic>
          ? _AdminBookingAddress.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      customQuoteStatus: json['customQuoteStatus'] as String?,
      customQuoteAmount: (json['customQuoteAmount'] as num?)?.toDouble(),
      customQuoteNotes: json['customQuoteNotes'] as String?,
      customQuoteItemized: json['customQuoteItemized'] as List<dynamic>?,
    );
  }
}

class _AdminBookingCustomer {
  const _AdminBookingCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String? phone;
  final String? avatarUrl;

  factory _AdminBookingCustomer.fromJson(Map<String, dynamic> json) {
    return _AdminBookingCustomer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Customer',
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class _AdminBookingWorker {
  const _AdminBookingWorker({
    required this.id,
    required this.fullName,
  });

  final String id;
  final String? fullName;

  factory _AdminBookingWorker.fromJson(Map<String, dynamic> json) {
    return _AdminBookingWorker(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String?,
    );
  }
}

class _AdminBookingAddress {
  const _AdminBookingAddress({
    required this.id,
    required this.label,
    required this.line1,
    required this.cityName,
  });

  final String id;
  final String? label;
  final String? line1;
  final String? cityName;

  factory _AdminBookingAddress.fromJson(Map<String, dynamic> json) {
    return _AdminBookingAddress(
      id: json['id'] as String? ?? '',
      label: json['label'] as String?,
      line1: json['line1'] as String?,
      cityName: json['cityName'] as String?,
    );
  }
}

class _AdminBookingPayment {
  const _AdminBookingPayment({
    required this.status,
    required this.amount,
    required this.gateway,
    required this.gatewayPaymentId,
    required this.gatewayOrderId,
    required this.updatedAt,
  });

  final String status;
  final double amount;
  final String? gateway;
  final String? gatewayPaymentId;
  final String? gatewayOrderId;
  final DateTime updatedAt;

  factory _AdminBookingPayment.fromJson(Map<String, dynamic> json) {
    return _AdminBookingPayment(
      status: json['status'] as String? ?? 'PENDING',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      gateway: json['gateway'] as String?,
      gatewayPaymentId: json['gatewayPaymentId'] as String?,
      gatewayOrderId: json['gatewayOrderId'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class _AdminBookingService {
  const _AdminBookingService({
    required this.serviceId,
    required this.serviceName,
  });

  final String? serviceId;
  final String serviceName;

  factory _AdminBookingService.fromJson(Map<String, dynamic> json) {
    return _AdminBookingService(
      serviceId: json['serviceId'] as String?,
      serviceName: json['serviceName'] as String? ?? 'Service',
    );
  }
}

class _AdminBookingTimelineEvent {
  const _AdminBookingTimelineEvent({
    required this.status,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final String status;
  final String title;
  final String description;
  final DateTime createdAt;

  factory _AdminBookingTimelineEvent.fromJson(Map<String, dynamic> json) {
    return _AdminBookingTimelineEvent(
      status: json['status'] as String? ?? '',
      title: json['title'] as String? ?? 'Event',
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final _AdminBookingPayment payment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${payment.status} • ₹${payment.amount.toStringAsFixed(0)}',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${payment.gateway ?? 'Gateway'} • ${DateFormat('d MMM y, h:mm a').format(payment.updatedAt)}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (payment.gatewayPaymentId != null || payment.gatewayOrderId != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (payment.gatewayPaymentId != null) 'Payment ID: ${payment.gatewayPaymentId}',
                if (payment.gatewayOrderId != null) 'Order ID: ${payment.gatewayOrderId}',
              ].join(' • '),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({required this.event});

  final _AdminBookingTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(event.description, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                DateFormat('d MMM y, h:mm a').format(event.createdAt),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'COMPLETED' => const Color(0xFF10B981),
    'CANCELLED' || 'REFUNDED' => const Color(0xFFEF4444),
    'IN_PROGRESS' || 'ARRIVED' || 'EN_ROUTE' => const Color(0xFF6366F1),
    'WORKER_ASSIGNED' || 'ACCEPTED' => const Color(0xFFF59E0B),
    _ => const Color(0xFF0F766E),
  };
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(child: child);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

class _CustomQuoteCard extends ConsumerWidget {
  const _CustomQuoteCard({
    required this.bookingId,
    required this.status,
    this.amount,
    this.notes,
    this.itemized,
    required this.onReload,
  });

  final String bookingId;
  final String status;
  final double? amount;
  final String? notes;
  final List<dynamic>? itemized;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color badgeColor;
    String badgeText;

    switch (status) {
      case 'REQUESTED':
        badgeColor = Colors.orange;
        badgeText = 'Quote Requested by Customer';
        break;
      case 'SUBMITTED':
        badgeColor = Colors.blue;
        badgeText = 'Quote Submitted — Awaiting Customer Response';
        break;
      case 'ACCEPTED':
        badgeColor = Colors.green;
        badgeText = 'Quote Accepted ✅';
        break;
      case 'DECLINED':
        badgeColor = Colors.red;
        badgeText = 'Quote Declined';
        break;
      default:
        badgeColor = cs.primary;
        badgeText = status;
    }

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeText,
                style: tt.labelMedium?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (status == 'REQUESTED') ...[
              const Text('The customer has requested a custom quote for this job.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => _SubmitQuoteDialog(bookingId: bookingId),
                    );
                    if (result == true) {
                      onReload();
                    }
                  },
                  child: const Text('Submit Quote'),
                ),
              ),
            ] else if (status == 'SUBMITTED' || status == 'ACCEPTED') ...[
              if (amount != null)
                _DetailRow(label: 'Total Amount', value: '₹${amount!.toStringAsFixed(0)}'),
              if (notes != null && notes!.isNotEmpty)
                _DetailRow(label: 'Notes', value: notes!),
              if (itemized != null && itemized!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Itemized Breakdown:', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...itemized!.map((item) {
                  final map = item as Map<String, dynamic>;
                  final label = map['label'] as String? ?? 'Item';
                  final price = (map['price'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 8),
                    child: Text('• $label: ₹${price.toStringAsFixed(0)}'),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SubmitQuoteDialog extends ConsumerStatefulWidget {
  const _SubmitQuoteDialog({required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<_SubmitQuoteDialog> createState() => _SubmitQuoteDialogState();
}

class _SubmitQuoteDialogState extends ConsumerState<_SubmitQuoteDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<Map<String, dynamic>> _itemized = [];
  bool _submitting = false;

  void _addItem() {
    setState(() {
      _itemized.add({'label': '', 'price': 0.0});
    });
  }

  void _removeItem(int index) {
    setState(() {
      _itemized.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/bookings/${widget.bookingId}/custom-quote/submit', data: {
        'amount': amount,
        'notes': _notesCtrl.text,
        'itemized': _itemized,
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Custom Quote'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Total Amount (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Itemized Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: _addItem,
                    child: const Text('Add Item'),
                  ),
                ],
              ),
              ..._itemized.asMap().entries.map((e) {
                final i = e.key;
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: _itemized[i]['label'] as String,
                        decoration: const InputDecoration(hintText: 'Label'),
                        onChanged: (v) => _itemized[i]['label'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: (_itemized[i]['price'] as double).toString(),
                        decoration: const InputDecoration(hintText: 'Price'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _itemized[i]['price'] = double.tryParse(v) ?? 0.0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeItem(i),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const CircularProgressIndicator() : const Text('Submit'),
        ),
      ],
    );
  }
}
