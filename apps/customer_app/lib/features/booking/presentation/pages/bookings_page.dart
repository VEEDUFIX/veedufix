import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/payments/booking_payments_api.dart';
import '../../../../core/payments/razorpay_service.dart';
import '../../../../core/realtime/realtime_socket_service.dart';
import '../../../profile/data/saved_addresses_api.dart';

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  late final RazorpayService _razorpayService;
  late final BookingPaymentApi _paymentsApi;
  late final SavedAddressesApi _addressesApi;
  WebSocketChannel? _trackingChannel;
  StreamSubscription? _trackingSubscription;
  _PendingPayment? _pendingPayment;
  String? _processingPlanId;
  String? _defaultAddressSummary;
  bool _loadingAddressSummary = true;
  final Set<String> _paidPlanIds = <String>{};

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService.create();
    _paymentsApi = BookingPaymentApi(ref.read(apiClientProvider).dio);
    _addressesApi = SavedAddressesApi(ref.read(apiClientProvider).dio);
    _razorpayService.registerCallbacks(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
    );
    _loadDefaultAddressSummary();
  }

  Future<void> _loadDefaultAddressSummary() async {
    try {
      final addresses = await _addressesApi.listAddresses();
      if (!mounted) {
        return;
      }
      final defaultAddress = addresses.firstWhere(
        (address) => address.isDefault,
        orElse: () => addresses.isNotEmpty ? addresses.first : const SavedAddressItem(
          id: '',
          label: '',
          addressLine1: '',
          city: '',
          pincode: '',
          lat: 0,
          lng: 0,
          isDefault: false,
        ),
      );
      setState(() {
        _defaultAddressSummary = defaultAddress.id.isEmpty ? null : '${defaultAddress.label} - ${defaultAddress.displayAddress}';
        _loadingAddressSummary = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _defaultAddressSummary = null;
        _loadingAddressSummary = false;
      });
    }
  }

  @override
  void dispose() {
    _disposeTrackingSocket();
    _razorpayService.dispose();
    super.dispose();
  }

  void _disposeTrackingSocket() {
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _trackingChannel?.sink.close();
    _trackingChannel = null;
  }

  void _connectTrackingSocket(String bookingId) {
    _disposeTrackingSocket();

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return;
    }

    final environment = ref.read(environmentProvider);
    _trackingChannel = connectTrackingSocket(
      apiBaseUrl: environment.apiBaseUrl,
      token: session.accessToken,
      bookingId: bookingId,
    );

    _trackingSubscription = _trackingChannel!.stream.listen(
      (message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          final type = decoded['type'] as String?;
          final payload = decoded['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};

          if (type == 'tracking.event') {
            final status = payload['status'] as String? ?? 'UPDATED';
            final label = payload['message'] as String? ?? 'Booking updated';
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$status: $label')),
            );

            if (_handleOtpNavigation(payload)) {
              return;
            }

            if (status == 'PAYMENT_CAPTURED') {
              final pending = _pendingPayment;
              if (pending != null) {
                setState(() {
                  _paidPlanIds.add(pending.planId);
                  _processingPlanId = null;
                  _pendingPayment = null;
                });
              }
            }
          }
        } catch (_) {
          // Ignore malformed server messages.
        }
      },
      onError: (_) {
        _disposeTrackingSocket();
      },
    );
  }

  bool _handleOtpNavigation(Map<String, dynamic> payload) {
    final eventType = payload['eventType'] as String? ?? payload['type'] as String?;
    final data = payload['data'];
    final bookingId = payload['bookingId'] as String? ??
        payload['booking_id'] as String? ??
        (data is Map<String, dynamic>
            ? (data['bookingId'] as String? ?? data['booking_id'] as String?)
            : null);

    if (eventType == null || bookingId == null || bookingId.isEmpty) {
      return false;
    }

    final route = switch (eventType) {
      'arrival_status_changed' when payload['status'] == 'arrived' =>
        '/arrival-otp?bookingId=$bookingId',
      'completion_otp_requested' => '/completion-otp?bookingId=$bookingId',
      _ => null,
    };

    if (route == null) {
      return false;
    }

    if (!mounted) {
      return false;
    }

    context.push(route);
    return true;
  }

  Future<void> _startCheckout(_BookingPlan plan) async {
    if (_processingPlanId != null) {
      return;
    }

    setState(() {
      _processingPlanId = plan.id;
    });

    try {
      final order = await _paymentsApi.createOrder(
        amountPaise: plan.amountPaise,
        description: plan.title,
      );

      _pendingPayment = _PendingPayment(
        planId: plan.id,
        order: order,
      );
      _connectTrackingSocket(order.bookingId);
      final session = ref.read(authControllerProvider).valueOrNull;
      final user = session?.user;

      _razorpayService.openCheckout(
        keyId: order.keyId,
        orderId: order.orderId,
        bookingCode: order.bookingCode,
        customerName: order.customerName.isNotEmpty ? order.customerName : user?.name ?? 'Customer',
        email: order.customerEmail ?? user?.email ?? 'customer@veedufix.local',
        phone: order.customerPhone ?? user?.phone ?? '+919999999999',
        amountInPaise: order.amountPaise,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processingPlanId = null;
        _pendingPayment = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start payment: $error')),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final pending = _pendingPayment;
    if (pending == null) {
      return;
    }

    try {
      await _paymentsApi.verifyPayment(
        bookingId: pending.order.bookingId,
        razorpayOrderId: response.orderId ?? pending.order.orderId,
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _paidPlanIds.add(pending.planId);
        _processingPlanId = null;
        _pendingPayment = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment verified successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processingPlanId = null;
        _pendingPayment = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment verification failed: $error')),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) {
      return;
    }
    setState(() {
      _processingPlanId = null;
      _pendingPayment = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message ?? 'Unknown error'}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${response.walletName ?? 'wallet'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.receipt_long_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    PremiumGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              height: 58,
                              width: 58,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.route_rounded,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your booking journey is live',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Track, pay, and confirm services in one calm, premium flow.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const TabBar(
                      tabs: [
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
                  children: [
                    _UpcomingBookingsTab(
                      isPaid: _paidPlanIds.contains('ac-service'),
                      isProcessing: _processingPlanId == 'ac-service',
                      defaultAddressSummary: _defaultAddressSummary,
                      isLoadingAddressSummary: _loadingAddressSummary,
                      onManageAddresses: () => context.push('/addresses'),
                      onPayNow: _paidPlanIds.contains('ac-service') || _processingPlanId == 'ac-service'
                          ? null
                          : () => _startCheckout(
                                const _BookingPlan(
                                  id: 'ac-service',
                                  title: 'AC service for 2BHK flat',
                                  amountPaise: 24900,
                                ),
                              ),
                    ),
                    const _BookingListTab(
                      emptyTitle: 'Nothing completed yet',
                      emptySubtitle: 'Completed jobs will appear here with invoice access and ratings.',
                      bookings: [
                        _BookingItem(
                          status: 'Completed',
                          title: 'Kitchen plumbing fix',
                          subtitle: '24 Jul 2026',
                          amountLabel: 'Rs 349',
                          accent: Color(0xFF10B981),
                        ),
                        _BookingItem(
                          status: 'Completed',
                          title: 'Bed assembly service',
                          subtitle: '19 Jul 2026',
                          amountLabel: 'Rs 499',
                          accent: Color(0xFFC2A15E),
                        ),
                      ],
                    ),
                    const _BookingListTab(
                      emptyTitle: 'No cancelled bookings',
                      emptySubtitle: 'If a booking is cancelled, the reason and refund status will be shown here.',
                      bookings: [
                        _BookingItem(
                          status: 'Cancelled',
                          title: 'Painting consultation',
                          subtitle: '20 Jun 2026',
                          amountLabel: 'Rs 299',
                          accent: Color(0xFFEF4444),
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
    );
  }
}

class _UpcomingBookingsTab extends StatelessWidget {
  const _UpcomingBookingsTab({
    required this.isPaid,
    required this.isProcessing,
    required this.defaultAddressSummary,
    required this.isLoadingAddressSummary,
    required this.onManageAddresses,
    required this.onPayNow,
  });

  final bool isPaid;
  final bool isProcessing;
  final String? defaultAddressSummary;
  final bool isLoadingAddressSummary;
  final VoidCallback onManageAddresses;
  final VoidCallback? onPayNow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const PremiumSectionHeader(
          title: 'Upcoming',
          subtitle: 'Active jobs, due payments, and live tracking.',
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.location_on_rounded, color: colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service address',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLoadingAddressSummary
                            ? 'Loading your saved default address...'
                            : defaultAddressSummary ?? 'No saved address found. Add one before checkout.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onManageAddresses,
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AC service for 2BHK flat',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    _StatusChip(
                      label: 'Worker assigned',
                      accent: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Today, 3:30 PM - Kodambakkam',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.payments_rounded,
                        label: 'Amount',
                        value: 'Rs 249',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.schedule_rounded,
                        label: 'Duration',
                        value: '90 mins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: isPaid ? 1 : 0.72,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onPayNow,
                        icon: Icon(isProcessing ? Icons.hourglass_top_rounded : Icons.payments_rounded),
                        label: Text(
                          isPaid
                              ? 'Paid'
                              : isProcessing
                                  ? 'Processing...'
                                  : 'Pay now',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.local_phone_rounded),
                      label: const Text('Call worker'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const PremiumSectionHeader(
          title: 'Tracking',
          subtitle: 'Live booking status, ETA, and service updates.',
        ),
        const SizedBox(height: 12),
        const _TrackingCard(
          step: 'Worker en route',
          detail: 'Tracking socket will post real-time status here.',
        ),
        const SizedBox(height: 12),
        const _TrackingCard(
          step: 'Payment verified',
          detail: 'Receipt, invoice, and capture confirmation appear after checkout.',
        ),
      ],
    );
  }
}

class _BookingListTab extends StatelessWidget {
  const _BookingListTab({
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.bookings,
  });

  final String emptyTitle;
  final String emptySubtitle;
  final List<_BookingItem> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          PremiumEmptyState(
            icon: Icons.event_busy_rounded,
            title: emptyTitle,
            subtitle: emptySubtitle,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _BookingRecordCard(item: bookings[index]);
      },
    );
  }
}

class _BookingRecordCard extends StatelessWidget {
  const _BookingRecordCard({required this.item});

  final _BookingItem item;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: item.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.home_repair_service_rounded, color: item.accent),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            _StatusChip(label: item.status, accent: item.accent),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            item.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        trailing: Text(
          item.amountLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.step,
    required this.detail,
  });

  final String step;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.fiber_manual_record_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _BookingPlan {
  const _BookingPlan({
    required this.id,
    required this.title,
    required this.amountPaise,
  });

  final String id;
  final String title;
  final int amountPaise;
}

class _PendingPayment {
  const _PendingPayment({
    required this.planId,
    required this.order,
  });

  final String planId;
  final BookingPaymentOrder order;
}

class _BookingItem {
  const _BookingItem({
    required this.status,
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.accent,
  });

  final String status;
  final String title;
  final String subtitle;
  final String amountLabel;
  final Color accent;
}
