import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../profile/data/saved_addresses_api.dart';

final cartCheckoutAddressesProvider =
    FutureProvider.autoDispose<List<SavedAddressItem>>((ref) async {
      final api = ref.watch(apiClientProvider);
      return SavedAddressesApi(api.dio).listAddresses();
    });

class CustomerScheduleSlot {
  const CustomerScheduleSlot({
    required this.scheduledFor,
    required this.availableProviders,
  });

  final DateTime scheduledFor;
  final int availableProviders;

  factory CustomerScheduleSlot.fromJson(Map<String, dynamic> json) =>
      CustomerScheduleSlot(
        scheduledFor: DateTime.parse(json['scheduledFor'] as String).toLocal(),
        availableProviders: (json['availableProviders'] as num?)?.toInt() ?? 0,
      );
}

final cartCheckoutScheduleSlotsProvider = FutureProvider.autoDispose
    .family<List<CustomerScheduleSlot>, String>((ref, key) async {
      final pieces = key.split('|');
      final addressId = pieces[0];
      final serviceIds = pieces[1].split(',');
      final startDate = pieces[2];
      final api = ref.watch(apiClientProvider);
      final response = await api.get(
        '/schedule/slots',
        queryParameters: {
          'addressId': addressId,
          'serviceIds': serviceIds.join(','),
          'startDate': startDate,
          'days': 7,
        },
      );
      final data = response as Map<dynamic, dynamic>;
      final rawSlots = data['slots'];
      if (rawSlots is! List) return const <CustomerScheduleSlot>[];
      return rawSlots
          .whereType<Map>()
          .map(
            (slot) =>
                CustomerScheduleSlot.fromJson(slot.cast<String, dynamic>()),
          )
          .toList(growable: false);
    });

// ─── Entities ─────────────────────────────────────────────────────────────────

class CheckoutItem {
  const CheckoutItem({
    required this.serviceId,
    required this.serviceName,
    required this.price,
    this.quantity = 1,
    this.variantId,
    this.addonIds = const [],
    this.configurationLabel,
  });

  final String serviceId;
  final String serviceName;
  final double price;
  final int quantity;
  final String? variantId;
  final List<String> addonIds;
  final String? configurationLabel;

  double get total => price * quantity;

  Map<String, dynamic> toJson() => {
    'serviceId': serviceId,
    'quantity': quantity,
    if (variantId != null) 'variantId': variantId,
    if (addonIds.isNotEmpty) 'addonIds': addonIds,
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
      (ref) => _CheckoutNotifier(ref),
    );

class _CheckoutNotifier extends StateNotifier<AsyncValue<void>> {
  _CheckoutNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  PaymentOrder? lastOrder;

  Future<PaymentOrder?> createOrder({
    required String cityId,
    required String addressId,
    required List<CheckoutItem> items,
    DateTime? scheduledFor,
    String? couponCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.post(
        '/payments/create-order',
        data: {
          if (cityId.isNotEmpty) 'cityId': cityId,
          'addressId': addressId,
          'items': items.map((i) => i.toJson()).toList(),
          if (couponCode != null && couponCode.isNotEmpty)
            'couponCode': couponCode,
          'bookingType': scheduledFor == null ? 'instant' : 'scheduled',
          if (scheduledFor != null)
            'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        },
      );
      final order = PaymentOrder.fromJson(
        (data as Map<dynamic, dynamic>).cast<String, dynamic>(),
      );
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
  const CheckoutPage({super.key, required this.cityId, required this.items});

  final String cityId;
  final List<CheckoutItem> items;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _couponController = TextEditingController();
  final _razorpay = Razorpay();
  bool _couponApplied = false;
  bool _promoExpanded = false;
  bool _isLaunchingPayment = false;
  bool _isVerifyingPayment = false;
  bool _paymentAttemptFailed = false;
  bool _paymentVerificationFailed = false;
  bool _scheduleForLater = false;
  String? _selectedAddressId;
  String? _verificationOrderId;
  String? _verificationPaymentId;
  String? _verificationSignature;
  DateTime _selectedScheduleDate = DateTime.now();
  String? _selectedScheduleSlot;
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

  double get _subtotal => widget.items.fold(0, (sum, i) => sum + i.total);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final checkoutState = ref.watch(checkoutProvider);
    final isLoading = checkoutState.isLoading;
    final orderLocked = _activeOrder != null || isLoading;
    final addressesState = ref.watch(cartCheckoutAddressesProvider);
    final addresses = addressesState.valueOrNull ?? const <SavedAddressItem>[];
    final selectedAddress = _resolveSelectedAddress(addresses);
    final scheduleDays = List<DateTime>.generate(7, (index) {
      final today = DateTime.now();
      return DateTime(today.year, today.month, today.day + index);
    }, growable: false);
    final scheduleKey = selectedAddress == null
        ? null
        : '${selectedAddress.id}|${widget.items.map((item) => item.serviceId).toSet().join(',')}|${_dateKey(scheduleDays.first)}';
    final slotsState = scheduleKey == null
        ? null
        : ref.watch(cartCheckoutScheduleSlotsProvider(scheduleKey));
    final slotsForDay =
        (slotsState?.valueOrNull ?? const <CustomerScheduleSlot>[])
            .where(
              (slot) =>
                  _dateKey(slot.scheduledFor) ==
                      _dateKey(_selectedScheduleDate) &&
                  slot.availableProviders > 0 &&
                  slot.scheduledFor.isAfter(DateTime.now()),
            )
            .toList(growable: false);
    final selectedSlotIso =
        slotsForDay.any(
          (slot) =>
              slot.scheduledFor.toUtc().toIso8601String() ==
              _selectedScheduleSlot,
        )
        ? _selectedScheduleSlot
        : (slotsForDay.isEmpty
              ? null
              : slotsForDay.first.scheduledFor.toUtc().toIso8601String());
    final needsNewOrder = _activeOrder == null;

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
        title: Text(
          'Checkout',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: widget.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 56,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No services to check out',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a service to your cart before booking.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.go('/search'),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Browse services'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ── Order summary ───────────────────────────────────────────────
                const _SectionHeader(title: 'Order summary'),
                const SizedBox(height: 10),
                PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        ...widget.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.serviceName,
                                        style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if ((item.configurationLabel ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          item.configurationLabel!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                      Text(
                                        '× ${item.quantity}',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${item.total.toStringAsFixed(2)}',
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '₹${_subtotal.toStringAsFixed(2)}',
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Taxes & fees',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Confirmed before payment',
                              textAlign: TextAlign.end,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const _SectionHeader(title: 'Service address'),
                const SizedBox(height: 10),
                PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: addressesState.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : addressesState.hasError
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Couldn't load your saved addresses.",
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _checkoutAddressErrorMessage(
                                  addressesState.error,
                                ),
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 0,
                                children: [
                                  TextButton(
                                    onPressed: orderLocked
                                        ? null
                                        : _openAddresses,
                                    child: const Text('Manage addresses'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => ref.invalidate(
                                      cartCheckoutAddressesProvider,
                                    ),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : addresses.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Where should we provide the service?',
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text('No saved address yet.'),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: orderLocked
                                      ? null
                                      : _openAddresses,
                                  icon: const Icon(
                                    Icons.add_location_alt_outlined,
                                  ),
                                  label: const Text('Add address'),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey(selectedAddress?.id),
                                initialValue: selectedAddress?.id,
                                onChanged: orderLocked
                                    ? null
                                    : (value) => setState(
                                        () => _selectedAddressId = value,
                                      ),
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Where should we provide the service?',
                                  border: OutlineInputBorder(),
                                ),
                                items: addresses
                                    .map(
                                      (address) => DropdownMenuItem<String>(
                                        value: address.id,
                                        child: Text(
                                          '${address.label} · ${address.city} ${address.pincode}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              if (selectedAddress != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  selectedAddress.displayAddress,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: orderLocked
                                      ? null
                                      : _openAddresses,
                                  icon: const Icon(
                                    Icons.edit_location_alt_outlined,
                                  ),
                                  label: const Text('Manage addresses'),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                const _SectionHeader(title: 'When do you need the service?'),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Instant')),
                    ButtonSegment(value: true, label: Text('Schedule')),
                  ],
                  selected: {_scheduleForLater},
                  onSelectionChanged: orderLocked
                      ? null
                      : (selection) => setState(() {
                          _scheduleForLater = selection.first;
                          _selectedScheduleSlot = null;
                        }),
                ),
                if (!_scheduleForLater) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Available as soon as a professional accepts your request.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (_scheduleForLater) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: scheduleDays.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final date = scheduleDays[index];
                        final selected =
                            _dateKey(date) == _dateKey(_selectedScheduleDate);
                        return ChoiceChip(
                          selected: selected,
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(index == 0 ? 'Today' : _weekdayShort(date)),
                              Text('${date.day}/${date.month}'),
                            ],
                          ),
                          onSelected: orderLocked
                              ? null
                              : (_) => setState(() {
                                  _selectedScheduleDate = date;
                                  _selectedScheduleSlot = null;
                                }),
                        );
                      },
                    ),
                  ),
                  if (selectedAddress == null)
                    const Text(
                      'Choose a service address to see available times.',
                    )
                  else if (slotsState?.isLoading ?? true)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (slotsState?.hasError ?? false)
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Could not load available times.'),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            cartCheckoutScheduleSlotsProvider(scheduleKey!),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else if (slotsForDay.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No appointment times are available on this day. Choose another date.',
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slotsForDay
                          .map((slot) {
                            final slotIso = slot.scheduledFor
                                .toUtc()
                                .toIso8601String();
                            final selected = slotIso == selectedSlotIso;
                            final time = TimeOfDay.fromDateTime(
                              slot.scheduledFor,
                            ).format(context);
                            return ChoiceChip(
                              selected: selected,
                              label: Text(time),
                              onSelected: orderLocked
                                  ? null
                                  : (_) => setState(
                                      () => _selectedScheduleSlot = slotIso,
                                    ),
                            );
                          })
                          .toList(growable: false),
                    ),
                ],
                const SizedBox(height: 20),

                // ── Promo code ──────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        leading: Icon(
                          _couponApplied
                              ? Icons.check_circle_outline_rounded
                              : Icons.local_offer_outlined,
                          color: _couponApplied
                              ? VeeduFixDesignSystem.success
                              : cs.primary,
                        ),
                        title: Text(
                          _couponApplied
                              ? '${_couponController.text} added'
                              : 'Have a promo code?',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Icon(
                          _promoExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.chevron_right_rounded,
                        ),
                        onTap: orderLocked
                            ? null
                            : () => setState(
                                () => _promoExpanded = !_promoExpanded,
                              ),
                      ),
                      if (_promoExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _couponController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  enabled: !_couponApplied && !orderLocked,
                                  decoration: InputDecoration(
                                    hintText: 'Enter coupon code',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: orderLocked
                                    ? null
                                    : _couponApplied
                                    ? () => setState(() {
                                        _couponApplied = false;
                                        _couponController.clear();
                                      })
                                    : _applyCoupon,
                                child: Text(
                                  _couponApplied ? 'Remove' : 'Apply',
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_couponApplied)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Discount is confirmed when the order is prepared.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Price summary ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price summary',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PriceRow(
                        label: widget.items.length == 1
                            ? 'Service'
                            : 'Services',
                        value: _formatCheckoutMoney(_subtotal),
                      ),
                      if (_activeOrder != null) ...[
                        const SizedBox(height: 10),
                        Divider(color: cs.outlineVariant),
                        _PriceRow(
                          label: 'Total',
                          value: _formatCheckoutMoney(
                            _activeOrder!.amountRupees,
                          ),
                          emphasized: true,
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        Text(
                          'Taxes and any applicable discount are confirmed before payment.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
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
                        Icon(
                          Icons.error_outline_rounded,
                          color: cs.error,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _checkoutErrorMessage(checkoutState.error),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_paymentVerificationFailed) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Payment may have been received, but booking confirmation is pending. Please contact support instead of trying to pay again.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(
                      '/support?autoCompose=true&category=payment&subject=${Uri.encodeComponent('Payment confirmation pending')}&message=${Uri.encodeComponent('My payment may have been received, but the booking confirmation did not complete. Please check the payment and booking status.')}',
                    ),
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Contact support'),
                  ),
                  if (_verificationOrderId != null &&
                      _verificationPaymentId != null &&
                      _verificationSignature != null)
                    TextButton.icon(
                      onPressed: _isVerifyingPayment
                          ? null
                          : _retryPaymentVerification,
                      icon: _isVerifyingPayment
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        _isVerifyingPayment
                            ? 'Confirming payment…'
                            : 'Retry confirmation',
                      ),
                    ),
                ],
                if (_paymentAttemptFailed && _activeOrder != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Payment was not completed. Booking ${_activeOrder!.bookingCode} is saved. Retry uses this booking and its original details; it will not create another booking.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 17,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secure payment · Your payment information is securely processed.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

      // ── Pay button ─────────────────────────────────────────────────────
      bottomNavigationBar: widget.items.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
                boxShadow: [
                  BoxShadow(
                    color: VeeduFixDesignSystem.ink.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatCheckoutMoney(
                                _activeOrder?.amountRupees ?? _subtotal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: VeeduFixDesignSystem.buttonHeight,
                          child: FilledButton(
                            onPressed:
                                isLoading ||
                                    _isLaunchingPayment ||
                                    _isVerifyingPayment ||
                                    _paymentVerificationFailed ||
                                    (needsNewOrder &&
                                        (addressesState.isLoading ||
                                            selectedAddress == null ||
                                            (_scheduleForLater &&
                                                ((slotsState?.isLoading ??
                                                        true) ||
                                                    selectedSlotIso == null))))
                                ? null
                                : () => _pay(
                                    selectedAddress?.id ?? '',
                                    scheduledFor:
                                        needsNewOrder && _scheduleForLater
                                        ? DateTime.parse(
                                            selectedSlotIso!,
                                          ).toUtc()
                                        : null,
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: VeeduFixDesignSystem.gold,
                              foregroundColor: VeeduFixDesignSystem.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  VeeduFixDesignSystem.radiusMedium,
                                ),
                              ),
                            ),
                            child: isLoading || _isLaunchingPayment
                                ? const Text('Continuing...')
                                : _isVerifyingPayment
                                ? const Text('Confirming payment...')
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _paymentAttemptFailed
                                          ? 'Retry payment'
                                          : 'Continue to payment  →',
                                      style: tt.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    if (!RegExp(r'^[A-Z0-9_-]{2,64}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid promo code.')),
      );
      return;
    }
    _couponController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    setState(() {
      _couponApplied = true;
      _promoExpanded = false;
    });
  }

  SavedAddressItem? _resolveSelectedAddress(List<SavedAddressItem> addresses) {
    if (_selectedAddressId != null) {
      for (final address in addresses) {
        if (address.id == _selectedAddressId) return address;
      }
    }
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  Future<void> _openAddresses() async {
    await context.push('/addresses');
    if (mounted) ref.invalidate(cartCheckoutAddressesProvider);
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _weekdayShort(DateTime date) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

  Future<void> _pay(String addressId, {DateTime? scheduledFor}) async {
    if (_isLaunchingPayment || _paymentVerificationFailed) return;

    final existingOrder = _activeOrder;
    if (existingOrder != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Retry payment?'),
          content: Text(
            'This will retry payment for booking ${existingOrder.bookingCode}. It will not create a new booking.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Retry payment'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      await _launchPaymentCheckout(existingOrder);
      return;
    }

    setState(() => _isLaunchingPayment = true);
    try {
      final order = await ref
          .read(checkoutProvider.notifier)
          .createOrder(
            cityId: widget.cityId,
            addressId: addressId,
            items: widget.items,
            scheduledFor: scheduledFor,
            couponCode: _couponApplied ? _couponController.text.trim() : null,
          );

      if (order == null || !mounted) {
        if (mounted) setState(() => _isLaunchingPayment = false);
        return;
      }
      if (order.keyId.isEmpty ||
          order.bookingId.isEmpty ||
          order.orderId.isEmpty ||
          order.amountPaise <= 0) {
        throw StateError('The payment order response was incomplete.');
      }
      setState(() => _activeOrder = order);
      await _launchPaymentCheckout(order);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLaunchingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open payment. Please try again.'),
        ),
      );
    }
  }

  Future<void> _launchPaymentCheckout(PaymentOrder order) async {
    setState(() {
      _isLaunchingPayment = true;
      _paymentAttemptFailed = false;
    });
    try {
      _razorpay.open({
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
        'theme': {'color': '#C6A769'},
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLaunchingPayment = false;
        _paymentAttemptFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open payment. Please try again.'),
        ),
      );
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    final order = _activeOrder;
    if (order == null || _isVerifyingPayment) return;
    if (response.orderId == null ||
        response.paymentId == null ||
        response.signature == null ||
        response.orderId!.isEmpty ||
        response.paymentId!.isEmpty ||
        response.signature!.isEmpty) {
      setState(() {
        _isLaunchingPayment = false;
        _paymentVerificationFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment details could not be confirmed. Contact support before trying again.',
          ),
          backgroundColor: VeeduFixDesignSystem.warning,
        ),
      );
      return;
    }
    _verificationOrderId = response.orderId;
    _verificationPaymentId = response.paymentId;
    _verificationSignature = response.signature;
    await _verifyCapturedPayment(order);
  }

  Future<void> _retryPaymentVerification() async {
    final order = _activeOrder;
    if (order == null ||
        _verificationOrderId == null ||
        _verificationPaymentId == null ||
        _verificationSignature == null ||
        _isVerifyingPayment) {
      return;
    }
    await _verifyCapturedPayment(order);
  }

  Future<void> _verifyCapturedPayment(PaymentOrder order) async {
    if (!mounted) return;
    final orderId = _verificationOrderId;
    final paymentId = _verificationPaymentId;
    final signature = _verificationSignature;
    if (orderId == null || paymentId == null || signature == null) return;

    setState(() {
      _isVerifyingPayment = true;
      _paymentAttemptFailed = false;
    });
    final success = await ref
        .read(checkoutProvider.notifier)
        .verifyPayment(
          bookingId: order.bookingId,
          orderId: orderId,
          paymentId: paymentId,
          signature: signature,
        );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isVerifyingPayment = false;
        _paymentVerificationFailed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text('Booking confirmed! #${order.bookingCode}'),
            ],
          ),
          backgroundColor: VeeduFixDesignSystem.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      context.go('/booking/${Uri.encodeComponent(order.bookingId)}');
    } else {
      setState(() {
        _isVerifyingPayment = false;
        _paymentVerificationFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment captured but verification failed. Contact support.',
          ),
          backgroundColor: VeeduFixDesignSystem.warning,
        ),
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLaunchingPayment = false;
      _paymentAttemptFailed = true;
    });
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
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName}'),
      ),
    );
  }

  String _checkoutErrorMessage(Object? error) {
    if (error is DioException) {
      if (error.response?.statusCode == 400 && _couponApplied) {
        return 'That promo code could not be applied. Check the code or remove it to continue.';
      }
      if (error.response?.statusCode == 401) {
        return 'Please sign in again to continue with payment.';
      }
    }
    return 'We could not prepare your payment. Check your connection and try again.';
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
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: (emphasized ? textTheme.titleSmall : textTheme.bodyMedium)
                ?.copyWith(
                  color: emphasized ? color : color.withValues(alpha: 0.78),
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: (emphasized ? textTheme.titleSmall : textTheme.bodyMedium)
              ?.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

String _formatCheckoutMoney(double amount) {
  final formatted = amount == amount.truncateToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '₹$formatted';
}

String _checkoutAddressErrorMessage(Object? error) {
  if (error is! DioException) {
    return 'An unexpected error occurred while loading addresses. Please retry.';
  }

  final statusCode = error.response?.statusCode;
  if (statusCode == 401) {
    return 'Your session may have expired. Sign in again, then retry.';
  }
  if (statusCode == 403) {
    return 'This account is not allowed to access customer addresses.';
  }
  if (statusCode == 404) {
    return 'The address service could not be found. Please retry shortly.';
  }
  if (statusCode != null && statusCode >= 500) {
    return 'The address service is temporarily unavailable. Please retry.';
  }
  if (statusCode == 429) {
    return 'Too many requests. Wait a moment, then retry.';
  }

  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.connectionError) {
    return 'Could not reach VeeduFix. Check your internet connection and retry.';
  }

  return statusCode == null
      ? 'Could not reach VeeduFix. Check your internet connection and retry.'
      : 'Address request failed (HTTP $statusCode). Please retry.';
}
