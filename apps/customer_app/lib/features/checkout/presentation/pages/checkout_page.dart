import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

// ─── Entities ─────────────────────────────────────────────────────────────────

class CheckoutItem {
  const CheckoutItem({
    required this.serviceId,
    required this.serviceName,
    required this.price,
    this.quantity = 1,
  });

  final String serviceId;
  final String serviceName;
  final double price;
  final int quantity;

  double get total => price * quantity;

  Map<String, dynamic> toJson() => {
        'serviceId': serviceId,
        'quantity': quantity,
      };
}

class PaymentOrder {
  const PaymentOrder({
    required this.keyId,
    required this.bookingId,
    required this.bookingCode,
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
  });

  final String keyId;
  final String bookingId;
  final String bookingCode;
  final String orderId;
  final int amountPaise;
  final String currency;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;

  double get amountRupees => amountPaise / 100;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
        keyId: json['keyId'] as String? ?? '',
        bookingId: json['bookingId'] as String? ?? '',
        bookingCode: json['bookingCode'] as String? ?? '',
        orderId: json['orderId'] as String? ?? '',
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'INR',
        customerName: json['customerName'] as String? ?? '',
        customerEmail: json['customerEmail'] as String?,
        customerPhone: json['customerPhone'] as String?,
      );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final checkoutProvider =
    StateNotifierProvider<_CheckoutNotifier, AsyncValue<void>>(
        (ref) => _CheckoutNotifier(ref));

class _CheckoutNotifier extends StateNotifier<AsyncValue<void>> {
  _CheckoutNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  PaymentOrder? lastOrder;

  Future<PaymentOrder?> createOrder({
    required String cityId,
    required List<CheckoutItem> items,
    String? couponCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.post(
        '/payments/create-order',
        data: {
          'cityId': cityId,
          'items': items.map((i) => i.toJson()).toList(),
          if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
          'bookingType': 'scheduled',
        },
      );
      final order = PaymentOrder.fromJson((data as Map<dynamic, dynamic>).cast<String, dynamic>());
      lastOrder = order;
      state = const AsyncValue.data(null);
      return order;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> verifyPayment({
    required String bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      await api.post(
        '/payments/verify',
        data: {
          'bookingId': bookingId,
          'razorpayOrderId': orderId,
          'razorpayPaymentId': paymentId,
          'razorpaySignature': signature,
        },
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({
    super.key,
    required this.cityId,
    required this.items,
  });

  final String cityId;
  final List<CheckoutItem> items;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _couponController = TextEditingController();
  final _razorpay = Razorpay();
  bool _couponApplied = false;
  PaymentOrder? _activeOrder;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _couponController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  double get _subtotal =>
      widget.items.fold(0, (sum, i) => sum + i.total);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final checkoutState = ref.watch(checkoutProvider);
    final isLoading = checkoutState.isLoading;

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
        title: Text('Checkout', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          // ── Order summary ───────────────────────────────────────────────
          const _SectionHeader(title: 'Order Summary'),
          const SizedBox(height: 10),
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  ...widget.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.serviceName,
                                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  Text('× ${item.quantity}',
                                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Text(
                              '₹${item.total.toStringAsFixed(2)}',
                              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      Text('₹${_subtotal.toStringAsFixed(2)}',
                          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Taxes & fees', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      Text('Included', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Coupon code ─────────────────────────────────────────────────
          const _SectionHeader(title: 'Promo Code'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    prefixIcon: const Icon(Icons.discount_rounded, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  enabled: !_couponApplied,
                ),
              ),
              const SizedBox(width: 10),
              TapScale(
                onTap: _couponApplied
                    ? () => setState(() {
                          _couponApplied = false;
                          _couponController.clear();
                        })
                    : _applyCoupon,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _couponApplied ? cs.errorContainer : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _couponApplied ? 'Remove' : 'Apply',
                    style: tt.labelLarge?.copyWith(
                      color: _couponApplied ? cs.onErrorContainer : cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_couponApplied) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(
                  'Coupon "${_couponController.text}" applied!',
                  style: tt.bodySmall?.copyWith(color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // ── Total ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withValues(alpha: 0.1), cs.secondary.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Payable',
                        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_subtotal.toStringAsFixed(2)}',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.lock_rounded, color: cs.primary.withValues(alpha: 0.5), size: 28),
              ],
            ),
          ),

          // ── Error ───────────────────────────────────────────────────────
          if (checkoutState.hasError) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${checkoutState.error}',
                      style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),

      // ── Pay button ─────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : _pay,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Pay ₹${_subtotal.toStringAsFixed(2)} via Razorpay',
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
      ),
    );
  }

  void _applyCoupon() {
    if (_couponController.text.trim().isEmpty) { return; }
    setState(() => _couponApplied = true);
  }

  Future<void> _pay() async {
    final order = await ref.read(checkoutProvider.notifier).createOrder(
          cityId: widget.cityId,
          items: widget.items,
          couponCode: _couponApplied ? _couponController.text.trim() : null,
        );

    if (order == null || !mounted) { return; }
    setState(() => _activeOrder = order);

    final options = {
      'key': order.keyId,
      'amount': order.amountPaise,
      'currency': order.currency,
      'order_id': order.orderId,
      'name': 'VeeduFix',
      'description': 'Home Service Booking',
      'prefill': {
        'name': order.customerName,
        if (order.customerEmail != null) 'email': order.customerEmail,
        if (order.customerPhone != null) 'contact': order.customerPhone,
      },
      'theme': {'color': '#6366F1'},
    };

    _razorpay.open(options);
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final order = _activeOrder;
    if (order == null) { return; }

    final success = await ref.read(checkoutProvider.notifier).verifyPayment(
          bookingId: order.bookingId,
          orderId: response.orderId ?? order.orderId,
          paymentId: response.paymentId ?? '',
          signature: response.signature ?? '',
        );

    if (!mounted) { return; }

    if (success) {
      // Navigate to booking detail / confirmation
      context.go('/booking/${order.bookingId}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text('Booking confirmed! #${order.bookingCode}'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment captured but verification failed. Contact support.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${response.walletName}')),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
