import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../profile/data/saved_addresses_api.dart';

final savedAddressesProvider = FutureProvider.autoDispose<List<SavedAddressItem>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final dio = apiClient.dio;
  final api = SavedAddressesApi(dio);
  return api.listAddresses();
});

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({
    super.key,
    this.serviceId,
    this.serviceName,
    this.servicePrice,
  });

  final String? serviceId;
  final String? serviceName;
  final double? servicePrice;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  int _step = 0; // 0: Address, 1: DateTime, 2: Summary

  // ── State ────────────────────────────────────────────────────────────────
  int _selectedDate = 0;
  int _selectedSlot = 2;

  String? _appliedCoupon;
  SavedAddressItem? _selectedAddress;

  final List<String> _slots = const [
    '08:00 AM', '10:00 AM', '12:00 PM', '02:00 PM', '04:00 PM', '06:00 PM',
  ];

  late final List<DateTime> _dateObjects;
  late final List<String> _dates;

  late Razorpay _razorpay;
  bool _isProcessing = false;
  String? _pendingBookingId;
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _dateObjects = List.generate(5, (i) => DateTime.now().add(Duration(days: i)));
    _dates = _dateObjects.map(_formatDate).toList();
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final nowOnly = DateTime(now.year, now.month, now.day);
    final diff = dateOnly.difference(nowOnly).inDays;
    
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]} ${dt.day}';
  }

  DateTime _getScheduledDateTime() {
    final dt = _dateObjects[_selectedDate];
    final timeStr = _slots[_selectedSlot];
    final isPM = timeStr.contains('PM');
    final parts = timeStr.split(' ')[0].split(':');
    int hour = int.parse(parts[0]);
    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;
    return DateTime(dt.year, dt.month, dt.day, hour, int.parse(parts[1]));
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final bookingId = _pendingBookingId;
    final orderId = _pendingOrderId;
    
    if (bookingId == null || orderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful but booking details missing.')));
      }
      return;
    }

    try {
      setState(() => _isProcessing = true);
      final repo = ref.read(paymentRepositoryProvider);
      await repo.verifyPayment(
        bookingId: bookingId,
        razorpayOrderId: response.orderId ?? orderId,
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      // Clear cart on success
      ref.read(cartProvider.notifier).clearCart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Verified & Booking Confirmed!')));
      context.pushReplacement('/tracking?bookingId=$bookingId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${response.message}')));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('External Wallet: ${response.walletName}')));
  }

  Future<void> _openCheckout(String finalServiceId, double amount) async {
    if (_isProcessing) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    final user = session?.user;

    try {
      setState(() => _isProcessing = true);
      final repo = ref.read(paymentRepositoryProvider);
      
      final session = ref.read(authControllerProvider).valueOrNull;
      // App is only for Chennai — use user's cityId from auth session (parsed from JWT/me response)
      final cityId = session?.user.cityId ?? 'city_kochi';

      final orderData = await repo.createOrder(
        cityId: cityId,
        items: [
          {'serviceId': finalServiceId, 'quantity': 1}
        ],
        couponCode: _appliedCoupon,
        bookingType: 'SCHEDULED',
        scheduledFor: _getScheduledDateTime().toIso8601String(),
      );

      _pendingBookingId = orderData['bookingId'];
      _pendingOrderId = orderData['orderId'];

      final options = {
        'key': orderData['keyId'],
        'amount': orderData['amountPaise'],
        'name': 'Veedufix',
        'description': 'Booking ${_pendingBookingId ?? ""}',
        'order_id': orderData['orderId'],
        'prefill': {
          'contact': user?.phone ?? '9876543210',
          'email': user?.email ?? 'customer@veedufix.com'
        }
      };
      
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error initializing payment: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Resolve service data
    String resolvedServiceId = '';
    String resolvedServiceName = '';
    double resolvedServicePrice = 0.0;
    bool isLoadingService = false;

    if (widget.serviceId != null && widget.serviceName != null && widget.servicePrice != null) {
      resolvedServiceId = widget.serviceId!;
      resolvedServiceName = widget.serviceName!;
      resolvedServicePrice = widget.servicePrice!;
    } else {
      final cart = ref.watch(cartProvider);
      if (cart.isNotEmpty) {
        resolvedServiceId = cart.first.service.id;
        resolvedServiceName = cart.first.service.name;
        resolvedServicePrice = cart.first.service.startingPrice;
      } else if (widget.serviceId != null) {
        final serviceAsync = ref.watch(serviceDetailProvider(widget.serviceId!));
        serviceAsync.when(
          data: (service) {
            resolvedServiceId = service.id;
            resolvedServiceName = service.name;
            resolvedServicePrice = service.startingPrice;
          },
          loading: () => isLoadingService = true,
          error: (_, __) {},
        );
      }
    }

    final double gst = resolvedServicePrice * 0.18;
    final double totalAmount = resolvedServicePrice + gst;

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
                color: cs.surface,
                shape: BoxShape.circle,
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text(
          'Checkout',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: isLoadingService
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── Progress stepper ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: _Stepper(currentStep: _step),
                ),
                const Divider(height: 1),

                // ─── Step content ────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: switch (_step) {
                        0 => _StepAddress(
                            key: const ValueKey(0),
                            selectedAddress: _selectedAddress,
                            onAddressSelected: (address) {
                              setState(() {
                                _selectedAddress = address;
                              });
                            },
                            onChangeAddress: () => context.push('/addresses'),
                          ),
                        1 => _StepDateTime(
                            key: const ValueKey(1),
                            dates: _dates,
                            slots: _slots,
                            selectedDate: _selectedDate,
                            selectedSlot: _selectedSlot,
                            onDateSelected: (i) => setState(() => _selectedDate = i),
                            onSlotSelected: (i) => setState(() => _selectedSlot = i),
                          ),
                        2 => _StepSummary(
                            key: const ValueKey(2),
                            serviceName: resolvedServiceName,
                            address: _selectedAddress?.displayAddress ?? 'No address selected',
                            date: _dates[_selectedDate],
                            slot: _slots[_selectedSlot],
                            basePrice: resolvedServicePrice,
                            gst: gst,
                            couponCode: _appliedCoupon,
                            onApplyCoupon: () async {
                              final code = await context.push('/offers');
                              if (code != null && code is String) {
                                setState(() {
                                  _appliedCoupon = code;
                                });
                              }
                            },
                          ),
                        _ => const SizedBox(),
                      },
                    ),
                  ),
                ),

                // ─── Bottom CTA ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: SafeArea(
                    child: TapScale(
                      onTap: () {
                        if (_step == 0 && _selectedAddress == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select an address')),
                          );
                          return;
                        }
                        if (_step < 2) {
                          setState(() {
                            _step++;
                          });
                        } else {
                          _openCheckout(resolvedServiceId, totalAmount);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                          boxShadow: AbzioTheme.eliteShadow,
                        ),
                        child: Text(
                          _step < 2 
                              ? 'Continue' 
                              : _isProcessing
                                  ? 'Processing...'
                                  : 'Confirm & Pay  ₹${totalAmount.toStringAsFixed(0)}',
                          textAlign: TextAlign.center,
                          style: tt.titleMedium?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Stepper ───────────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = const ['Address', 'Date & Time', 'Summary'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // connector line
          final leftIndex = i ~/ 2;
          final filled = currentStep > leftIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: filled
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.4),
            ),
          );
        }
        final index = i ~/ 2;
        final active = index == currentStep;
        final done = index < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: active ? 32 : 28,
          height: active ? 32 : 28,
          decoration: BoxDecoration(
            color: done || active ? cs.primary : cs.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: active ? Colors.white : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}

// ── Step 0: Address ───────────────────────────────────────────────────────────

class _StepAddress extends ConsumerWidget {
  const _StepAddress({
    super.key,
    required this.selectedAddress,
    required this.onAddressSelected,
    required this.onChangeAddress,
  });
  final SavedAddressItem? selectedAddress;
  final ValueChanged<SavedAddressItem> onAddressSelected;
  final VoidCallback onChangeAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final addressesAsync = ref.watch(savedAddressesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Service Address', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Where should the professional go?', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 24),
        
        addressesAsync.when(
          data: (addresses) {
            if (addresses.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('No saved addresses found. Please add one.', 
                  style: tt.bodyMedium?.copyWith(color: cs.error)),
              );
            }

            // Auto-select first address if none selected
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (selectedAddress == null && addresses.isNotEmpty) {
                onAddressSelected(addresses.first);
              }
            });

            return Column(
              children: addresses.map((address) {
                final isSelected = selectedAddress?.id == address.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TapScale(
                    onTap: () => onAddressSelected(address),
                    child: PremiumCard(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                          border: isSelected ? Border.all(color: cs.primary, width: 2) : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(address.label.toLowerCase() == 'home' ? Icons.home_rounded : Icons.location_on_rounded, color: cs.primary),
                                const SizedBox(width: 10),
                                Text(address.label.isNotEmpty ? address.label : 'Saved Address',
                                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                const Spacer(),
                                if (address.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Default',
                                        style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                                  ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              address.displayAddress,
                              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('Failed to load addresses: $err', style: tt.bodyMedium?.copyWith(color: cs.error)),
          ),
        ),
        
        const SizedBox(height: 16),
        TapScale(
          onTap: () {
            // Placeholder for current location logic
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Locating...')));
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            ),
            child: Row(
              children: [
                Icon(Icons.my_location_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Text('Use current location', style: tt.bodyLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TapScale(
          onTap: onChangeAddress,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            ),
            child: Row(
              children: [
                Icon(Icons.add_location_alt_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Text('Add or manage addresses', style: tt.bodyLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step 1: Date & Time ───────────────────────────────────────────────────────

class _StepDateTime extends StatelessWidget {
  const _StepDateTime({
    super.key,
    required this.dates,
    required this.slots,
    required this.selectedDate,
    required this.selectedSlot,
    required this.onDateSelected,
    required this.onSlotSelected,
  });
  final List<String> dates;
  final List<String> slots;
  final int? selectedDate;
  final int? selectedSlot;
  final ValueChanged<int> onDateSelected;
  final ValueChanged<int> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Date', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final selected = selectedDate == i;
              return TapScale(
                onTap: () => onDateSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surface,
                    borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: Center(
                    child: Text(
                      dates[i],
                      textAlign: TextAlign.center,
                      style: tt.labelLarge?.copyWith(
                        color: selected ? cs.onPrimary : cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
        Text('Choose Time Slot', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemCount: slots.length,
          itemBuilder: (context, i) {
            final selected = selectedSlot == i;
            return TapScale(
              onTap: () => onSlotSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? null
                      : Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    slots[i],
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: selected ? cs.onPrimary : cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Step 2: Summary ───────────────────────────────────────────────────────────

class _StepSummary extends StatelessWidget {
  const _StepSummary({
    super.key,
    required this.serviceName,
    required this.address,
    required this.date,
    required this.slot,
    required this.basePrice,
    required this.gst,
    this.couponCode,
    required this.onApplyCoupon,
  });
  final String serviceName;
  final String address;
  final String date;
  final String slot;
  final double basePrice;
  final double gst;
  final String? couponCode;
  final VoidCallback onApplyCoupon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Summary', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _SummaryRow(icon: Icons.cleaning_services_rounded, label: 'Service', value: serviceName),
                const Divider(height: 24),
                _SummaryRow(icon: Icons.location_on_rounded, label: 'Address', value: address),
                const Divider(height: 24),
                _SummaryRow(icon: Icons.calendar_today_rounded, label: 'Date', value: date),
                const Divider(height: 24),
                _SummaryRow(icon: Icons.access_time_rounded, label: 'Time Slot', value: slot),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Bill Details', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _BillRow(label: 'Service charge', amount: basePrice),
                const SizedBox(height: 10),
                _BillRow(label: 'GST (18%)', amount: gst),
                if (couponCode != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discount ($couponCode)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
                      Text('-₹100',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF10B981), fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _BillRow(
                  label: 'Total',
                  amount: couponCode != null ? (basePrice + gst - 100) : (basePrice + gst),
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TapScale(
          onTap: onApplyCoupon,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            ),
            child: Row(
              children: [
                Icon(Icons.local_offer_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    couponCode != null ? 'Coupon $couponCode applied!' : 'View offers and coupons',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                if (couponCode == null)
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                if (couponCode != null)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Protected by Veedufix Guarantee',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.amount,
    this.isBold = false,
  });
  final String label;
  final double amount;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final style = isBold
        ? tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : tt.bodyLarge;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('₹${amount.toStringAsFixed(2)}', style: style),
      ],
    );
  }
}
