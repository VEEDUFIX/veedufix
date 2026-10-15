import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../profile/data/saved_addresses_api.dart';
import '../../../profile/presentation/pages/map_location_picker_page.dart';

final savedAddressesProvider =
    FutureProvider.autoDispose<List<SavedAddressItem>>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final dio = apiClient.dio;
      final api = SavedAddressesApi(dio);
      return api.listAddresses();
    });

class _PendingPaymentRecovery {
  const _PendingPaymentRecovery({
    required this.bookingId,
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String bookingId;
  final String orderId;
  final String paymentId;
  final String signature;

  bool get canVerify =>
      bookingId.trim().isNotEmpty &&
      orderId.trim().isNotEmpty &&
      paymentId.trim().isNotEmpty &&
      signature.trim().isNotEmpty;

  Map<String, String> toJson() => {
    'bookingId': bookingId,
    'orderId': orderId,
    'paymentId': paymentId,
    'signature': signature,
  };

  factory _PendingPaymentRecovery.fromStorage(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Invalid pending payment recovery data');
    }
    String read(String key) =>
        decoded[key] is String ? decoded[key] as String : '';
    return _PendingPaymentRecovery(
      bookingId: read('bookingId'),
      orderId: read('orderId'),
      paymentId: read('paymentId'),
      signature: read('signature'),
    );
  }
}

String _pendingPaymentStorageKey(String userId) =>
    'customer_pending_payment_${Uri.encodeComponent(userId)}';

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
  LatLng? _selectedGeoPoint;
  String? _selectedGeoLabel;

  final List<String> _slots = const [
    '08:00 AM',
    '10:00 AM',
    '12:00 PM',
    '02:00 PM',
    '04:00 PM',
    '06:00 PM',
  ];

  late final List<DateTime> _dateObjects;
  late final List<String> _dates;

  late Razorpay _razorpay;
  bool _isProcessing = false;
  bool _isLoadingPaymentRecovery = true;
  bool _paymentRecoveryLoadFailed = false;
  int _paymentRecoveryPlatformReadFailures = 0;
  String? _pendingPaymentUserId;
  String? _pendingBookingId;
  String? _pendingOrderId;
  _PendingPaymentRecovery? _pendingPaymentRecovery;
  bool _pendingPaymentRecoveryStorageFailed = false;
  final FlutterSecureStorage _paymentRecoveryStorage =
      const FlutterSecureStorage();
  String? _paymentVerificationError;
  bool _paymentVerificationRetryable = false;

  bool get _canRetryPaymentVerification =>
      _paymentVerificationRetryable &&
      _pendingPaymentRecovery?.canVerify == true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _dateObjects = List.generate(
      5,
      (i) => DateTime.now().add(Duration(days: i)),
    );
    _dates = _dateObjects.map(_formatDate).toList();
    unawaited(_restorePendingPaymentRecovery());
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

  String _selectedLocationSummary() {
    final address = _selectedAddress;
    if (address != null) {
      return address.displayAddress;
    }

    final point = _selectedGeoPoint;
    if (point != null) {
      if ((_selectedGeoLabel ?? '').trim().isNotEmpty) {
        return _selectedGeoLabel!.trim();
      }
      return 'Pinned location: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }

    return 'No address selected';
  }

  Future<void> _useCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Turn on location services to use your current position.',
            ),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required to use your current position.',
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      final picked = await context.push<MapLocationSelection>(
        '/map-picker?lat=${position.latitude}&lng=${position.longitude}',
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedGeoPoint = picked.location;
          _selectedGeoLabel = picked.label;
          _selectedAddress = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to use current location.')),
      );
    }
  }

  Future<bool> _checkPendingPaymentRecovery(String userId) async {
    try {
      final saved = await _paymentRecoveryStorage.read(
        key: _pendingPaymentStorageKey(userId),
      );
      if (saved == null) {
        _paymentRecoveryPlatformReadFailures = 0;
        return false;
      }
      final recovery = _PendingPaymentRecovery.fromStorage(saved);
      _paymentRecoveryPlatformReadFailures = 0;
      if (!mounted) return true;
      setState(() {
        _pendingPaymentUserId = userId;
        _pendingPaymentRecovery = recovery;
        _pendingBookingId = recovery.bookingId;
        _pendingOrderId = recovery.orderId;
        _paymentVerificationRetryable = recovery.canVerify;
        _paymentVerificationError = recovery.canVerify
            ? 'A previous payment is waiting for verification. Verify it before starting another payment.'
            : 'A previous payment needs support. Do not make another payment.';
      });
      return true;
    } on FormatException {
      if (!mounted) return true;
      setState(() {
        _pendingPaymentUserId = userId;
        _pendingPaymentRecovery = const _PendingPaymentRecovery(
          bookingId: '',
          orderId: '',
          paymentId: '',
          signature: '',
        );
        _pendingBookingId = null;
        _pendingOrderId = null;
        _paymentRecoveryLoadFailed = false;
        _paymentVerificationRetryable = false;
        _paymentVerificationError =
            'A saved payment record is unreadable. Contact support before clearing it or paying again.';
      });
      return true;
    } on PlatformException {
      _paymentRecoveryPlatformReadFailures++;
      if (!mounted) return true;
      final isPersistentFailure = _paymentRecoveryPlatformReadFailures >= 2;
      setState(() {
        _paymentRecoveryLoadFailed = !isPersistentFailure;
        _paymentVerificationRetryable = false;
        if (isPersistentFailure) {
          _pendingPaymentUserId = userId;
          _pendingPaymentRecovery = const _PendingPaymentRecovery(
            bookingId: '',
            orderId: '',
            paymentId: '',
            signature: '',
          );
          _pendingBookingId = null;
          _pendingOrderId = null;
          _paymentVerificationError =
              'Payment recovery storage is still unavailable after retry. Contact support before clearing it or paying again.';
        } else {
          _paymentVerificationError =
              'Could not check for a previous payment. Retry the check before making another payment.';
        }
      });
      return true;
    } catch (_) {
      if (!mounted) return true;
      setState(() {
        _paymentRecoveryLoadFailed = true;
        _paymentVerificationRetryable = false;
        _paymentVerificationError =
            'Could not check for a previous payment. Retry the check before making another payment.';
      });
      return true;
    }
  }

  Future<void> _restorePendingPaymentRecovery() async {
    try {
      final session = await ref.read(authControllerProvider.future);
      final userId = session?.user.id;
      if (userId == null || userId.isEmpty) return;
      await _checkPendingPaymentRecovery(userId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paymentRecoveryLoadFailed = true;
        _paymentVerificationRetryable = false;
        _paymentVerificationError =
            'Could not confirm your account or check for a previous payment. Retry the check before paying.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingPaymentRecovery = false);
    }
  }

  Future<void> _retryPendingPaymentRecoveryLoad() async {
    if (_isLoadingPaymentRecovery) return;
    setState(() {
      _isLoadingPaymentRecovery = true;
      _paymentRecoveryLoadFailed = false;
      _paymentVerificationError = null;
    });
    await _restorePendingPaymentRecovery();
  }

  Future<void> _savePendingPaymentRecovery(
    _PendingPaymentRecovery recovery,
  ) async {
    final userId =
        _pendingPaymentUserId ??
        ref.read(authControllerProvider).valueOrNull?.user.id;
    if (userId == null || userId.isEmpty) {
      throw StateError(
        'A signed-in customer is required to save payment recovery',
      );
    }
    await _paymentRecoveryStorage.write(
      key: _pendingPaymentStorageKey(userId),
      value: jsonEncode(recovery.toJson()),
    );
    _pendingPaymentUserId = userId;
  }

  Future<void> _clearPendingPaymentRecovery() async {
    final userId = _pendingPaymentUserId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Missing customer ID for payment recovery cleanup');
    }
    await _paymentRecoveryStorage.delete(
      key: _pendingPaymentStorageKey(userId),
    );
    if (!mounted) return;
    setState(() {
      _pendingPaymentRecovery = null;
      _pendingPaymentRecoveryStorageFailed = false;
      _pendingBookingId = null;
      _pendingOrderId = null;
      _pendingPaymentUserId = null;
      _paymentVerificationError = null;
      _paymentVerificationRetryable = false;
    });
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    final responseOrderId = response.orderId?.trim();
    final recovery = _PendingPaymentRecovery(
      bookingId: _pendingBookingId ?? '',
      orderId: responseOrderId == null || responseOrderId.isEmpty
          ? _pendingOrderId ?? ''
          : responseOrderId,
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
    );
    setState(() {
      _pendingPaymentRecovery = recovery;
      _pendingPaymentRecoveryStorageFailed = false;
      _isProcessing = true;
      _paymentVerificationRetryable = false;
      _paymentVerificationError = null;
    });
    var recoveryStorageFailed = false;
    try {
      await _savePendingPaymentRecovery(recovery);
    } catch (_) {
      recoveryStorageFailed = true;
      if (!mounted) return;
      setState(() {
        _pendingPaymentRecoveryStorageFailed = true;
        if (!recovery.canVerify) {
          _isProcessing = false;
          _paymentVerificationRetryable = false;
          _paymentVerificationError =
              'Payment succeeded, but recovery details could not be saved. Contact support; do not pay again.';
        }
      });
      if (!recovery.canVerify) return;
    }
    await _verifyPendingPayment(
      recovery,
      recoveryStorageFailed: recoveryStorageFailed,
    );
  }

  Future<void> _retryPaymentVerification() async {
    final recovery = _pendingPaymentRecovery;
    if (!_canRetryPaymentVerification || recovery == null || _isProcessing) {
      return;
    }
    var recoveryStorageFailed = _pendingPaymentRecoveryStorageFailed;
    if (recoveryStorageFailed) {
      setState(() => _isProcessing = true);
      try {
        await _savePendingPaymentRecovery(recovery);
        recoveryStorageFailed = false;
        if (mounted) {
          setState(() => _pendingPaymentRecoveryStorageFailed = false);
        }
      } catch (_) {
        // Continue with in-memory verification if persistence still fails.
      }
      if (!mounted) return;
    }
    await _verifyPendingPayment(
      recovery,
      recoveryStorageFailed: recoveryStorageFailed,
    );
  }

  Future<void> _contactSupportForPayment() async {
    final orderId = _pendingOrderId?.trim();
    final recoveryReason = _paymentVerificationError?.trim();
    final uri = Uri(
      path: '/support',
      queryParameters: {
        'autoCompose': 'true',
        'category': 'payment',
        'subject': 'Payment status needs verification',
        'message':
            'Payment recovery needs help. '
            '${recoveryReason?.isNotEmpty == true ? 'Current status: $recoveryReason ' : 'The payment status could not be confirmed. '}'
            'Order reference: '
            '${orderId?.isNotEmpty == true ? orderId : 'unavailable'}. '
            'Please verify the payment status before I try another payment.',
      },
    );
    await context.push<void>(uri.toString());
  }

  Future<void> _dismissResolvedPaymentRecovery() async {
    final recovery = _pendingPaymentRecovery;
    if (recovery == null ||
        _paymentRecoveryLoadFailed ||
        _paymentVerificationRetryable ||
        _isProcessing) {
      return;
    }

    final orderReference = _pendingOrderId?.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear resolved payment recovery?'),
        content: Text(
          'Only continue if VeeduFix Support confirmed that the previous charge '
          'was refunded or no payment is due. Clearing this record does not '
          'verify or refund a payment.\n\n'
          'Order reference: ${orderReference?.isNotEmpty == true ? orderReference : 'unavailable'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep recovery'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Support resolved it'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final userId =
        _pendingPaymentUserId ??
        ref.read(authControllerProvider).valueOrNull?.user.id;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in again before clearing payment recovery.'),
        ),
      );
      return;
    }

    try {
      await _paymentRecoveryStorage.delete(
        key: _pendingPaymentStorageKey(userId),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not clear payment recovery. Keep this checkout open and contact support.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _pendingPaymentRecovery = null;
      _pendingPaymentRecoveryStorageFailed = false;
      _pendingBookingId = null;
      _pendingOrderId = null;
      _pendingPaymentUserId = null;
      _paymentVerificationError = null;
      _paymentVerificationRetryable = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment recovery cleared. You can continue checkout.'),
      ),
    );
  }

  Future<void> _verifyPendingPayment(
    _PendingPaymentRecovery recovery, {
    bool recoveryStorageFailed = false,
  }) async {
    final bookingId = recovery.bookingId;
    final orderId = recovery.orderId;

    if (bookingId.trim().isEmpty || orderId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _paymentVerificationRetryable = false;
          _paymentVerificationError =
              'Payment completed, but booking details are missing. Contact support before trying another payment.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful but booking details missing.'),
          ),
        );
      }
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _paymentVerificationRetryable = false;
        _paymentVerificationError = null;
      });
      final repo = ref.read(paymentRepositoryProvider);
      final cartNotifier = ref.read(cartProvider.notifier);
      await repo.verifyPayment(
        bookingId: bookingId,
        razorpayOrderId: orderId,
        razorpayPaymentId: recovery.paymentId,
        razorpaySignature: recovery.signature,
      );

      try {
        await _clearPendingPaymentRecovery();
      } catch (_) {
        // Payment is confirmed; repeat verification is safe if local cleanup fails.
      }
      cartNotifier.clearCart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Verified & Booking Confirmed!')),
      );
      context.pushReplacement('/tracking?bookingId=$bookingId');
    } catch (error) {
      if (!mounted) return;
      final statusCode = error is DioException
          ? error.response?.statusCode
          : null;
      final permanentRejection =
          statusCode != null &&
          statusCode >= 400 &&
          statusCode < 500 &&
          statusCode != 401 &&
          statusCode != 408 &&
          statusCode != 429;
      setState(() {
        _paymentVerificationRetryable = !permanentRejection;
        final verificationMessage = permanentRejection
            ? 'Payment verification was rejected. Contact support; do not pay again.'
            : 'Payment succeeded, but booking verification failed. Retry verification; do not pay again.';
        _paymentVerificationError = recoveryStorageFailed
            ? '$verificationMessage Recovery details could not be saved; keep this screen open while resolving the payment.'
            : verificationMessage;
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    if (!mounted) return;
    final recovery = _pendingPaymentRecovery;
    if (response.code == Razorpay.PAYMENT_CANCELLED && recovery != null) {
      final cartNotifier = ref.read(cartProvider.notifier);
      setState(() {
        _isProcessing = true;
        _paymentVerificationRetryable = false;
        _paymentVerificationError = null;
      });
      try {
        final status = await ref
            .read(paymentRepositoryProvider)
            .getOrderStatus(
              bookingId: recovery.bookingId,
              razorpayOrderId: recovery.orderId,
            );
        if (!mounted) return;

        if (status == 'CAPTURED') {
          try {
            await _clearPendingPaymentRecovery();
          } catch (_) {
            // The server has confirmed capture; local cleanup can be retried
            // after the Customer reaches the confirmed booking.
          }
          cartNotifier.clearCart();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment confirmed. Booking received.'),
            ),
          );
          context.pushReplacement('/tracking?bookingId=${recovery.bookingId}');
          return;
        }

        if (status == 'FAILED') {
          try {
            await _clearPendingPaymentRecovery();
            if (!mounted) return;
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment cancelled. No payment was captured.'),
              ),
            );
          } catch (_) {
            if (!mounted) return;
            setState(() {
              _isProcessing = false;
              _paymentVerificationRetryable = false;
              _paymentVerificationError =
                  'No payment was captured, but local recovery could not be cleared. Contact support before retrying.';
            });
          }
          return;
        }

        setState(() {
          _isProcessing = false;
          _paymentVerificationRetryable = false;
          _paymentVerificationError =
              'Payment is still being resolved. Contact support before trying again.';
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _paymentVerificationRetryable = false;
          _paymentVerificationError =
              'Payment status could not be confirmed. Contact support before trying again.';
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment status needs confirmation.')),
      );
      return;
    }

    if (recovery != null) {
      setState(() {
        // The checkout SDK error is not authoritative proof that the provider
        // did not capture payment. Preserve the order record until Support
        // confirms its status so another payment cannot be started meanwhile.
        _paymentVerificationRetryable = false;
        _paymentVerificationError =
            'Payment status for this order is not confirmed. Contact support before trying again.';
      });
    }
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      if (_pendingPaymentRecovery != null) {
        _paymentVerificationRetryable = false;
        _paymentVerificationError =
            'The external wallet result is not confirmed. Contact support before trying another payment.';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  Future<void> _openCheckout(String finalServiceId) async {
    if (_isProcessing ||
        _isLoadingPaymentRecovery ||
        _paymentRecoveryLoadFailed ||
        _pendingPaymentRecovery != null) {
      return;
    }

    final session = ref.read(authControllerProvider).valueOrNull;
    final user = session?.user;
    final userId = user?.id.trim();
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again before starting a payment.'),
        ),
      );
      return;
    }
    final cityId = user?.cityId?.trim() ?? '';
    final phone = user?.phone?.trim() ?? '';
    final email = user?.email?.trim() ?? '';

    setState(() => _isLoadingPaymentRecovery = true);
    final hasPendingRecovery = await _checkPendingPaymentRecovery(userId);
    if (!mounted) return;
    if (hasPendingRecovery) {
      setState(() => _isLoadingPaymentRecovery = false);
      if (!_paymentRecoveryLoadFailed && _canRetryPaymentVerification) {
        await _retryPaymentVerification();
      }
      return;
    }

    try {
      setState(() {
        _isLoadingPaymentRecovery = false;
        _isProcessing = true;
      });
      final repo = ref.read(paymentRepositoryProvider);

      if (cityId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your city is missing from your profile. Please update your profile and try again.',
            ),
          ),
        );
        setState(() => _isProcessing = false);
        return;
      }

      final orderData = await repo.createOrder(
        cityId: cityId,
        items: [
          {'serviceId': finalServiceId, 'quantity': 1},
        ],
        couponCode: _appliedCoupon,
        bookingType: 'SCHEDULED',
        scheduledFor: _getScheduledDateTime().toIso8601String(),
      );

      if (!mounted) return;
      final bookingId = orderData['bookingId'];
      final orderId = orderData['orderId'];
      if (bookingId is! String ||
          bookingId.trim().isEmpty ||
          orderId is! String ||
          orderId.trim().isEmpty) {
        throw StateError(
          'Order response is missing booking or payment order details',
        );
      }
      _pendingBookingId = bookingId.trim();
      _pendingOrderId = orderId.trim();
      final partialRecovery = _PendingPaymentRecovery(
        bookingId: _pendingBookingId ?? '',
        orderId: _pendingOrderId ?? '',
        paymentId: '',
        signature: '',
      );
      setState(() {
        _pendingPaymentRecovery = partialRecovery;
        _pendingPaymentRecoveryStorageFailed = false;
        _paymentVerificationRetryable = false;
        _paymentVerificationError = null;
      });
      try {
        _pendingPaymentUserId = userId;
        await _savePendingPaymentRecovery(partialRecovery);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _pendingPaymentRecoveryStorageFailed = true;
          _paymentVerificationError =
              'Payment details could not be saved securely. The payment screen was not opened; contact support before retrying.';
          _isProcessing = false;
        });
        return;
      }
      if (!mounted) return;

      final options = {
        'key': orderData['keyId'],
        'amount': orderData['amountPaise'],
        'name': 'Veedufix',
        'description': 'Booking ${_pendingBookingId ?? ""}',
        'order_id': orderData['orderId'],
        if (phone.isNotEmpty || email.isNotEmpty)
          'prefill': {
            if (phone.isNotEmpty) 'contact': phone,
            if (email.isNotEmpty) 'email': email,
          },
      };

      _razorpay.open(options);
    } catch (error) {
      if (!mounted) return;
      final recovery = _pendingPaymentRecovery;
      var partialRecoveryCleared = false;
      var partialRecoveryCleanupFailed = false;
      if (recovery != null && !recovery.canVerify) {
        try {
          final recoveryUserId = _pendingPaymentUserId;
          if (recoveryUserId == null || recoveryUserId.isEmpty) {
            throw StateError(
              'Missing customer ID for payment recovery cleanup',
            );
          }
          await _paymentRecoveryStorage.delete(
            key: _pendingPaymentStorageKey(recoveryUserId),
          );
          partialRecoveryCleared = true;
        } catch (_) {
          partialRecoveryCleanupFailed = true;
        }
      }
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        if (partialRecoveryCleared) {
          _pendingPaymentRecovery = null;
          _pendingPaymentRecoveryStorageFailed = false;
          _pendingBookingId = null;
          _pendingOrderId = null;
          _pendingPaymentUserId = null;
          _paymentVerificationRetryable = false;
          _paymentVerificationError = null;
        } else if (_pendingPaymentRecovery != null) {
          _paymentVerificationRetryable = false;
          _paymentVerificationError = partialRecoveryCleanupFailed
              ? 'Payment status could not be safely cleared. Contact support before trying again.'
              : 'The payment order could not be opened or confirmed. Contact support before trying again.';
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_checkoutErrorMessage(error))));
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

    if (widget.serviceId != null &&
        widget.serviceName != null &&
        widget.servicePrice != null) {
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
        final serviceAsync = ref.watch(
          serviceDetailProvider(widget.serviceId!),
        );
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

    return PopScope(
      canPop: !_isProcessing && !_pendingPaymentRecoveryStorageFailed,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: TapScale(
              onTap: _isProcessing || _pendingPaymentRecoveryStorageFailed
                  ? null
                  : () => context.pop(),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
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
                            hasGeoSelection: _selectedGeoPoint != null,
                            onAddressSelected: (address) {
                              setState(() {
                                _selectedAddress = address;
                                _selectedGeoPoint = null;
                                _selectedGeoLabel = null;
                              });
                            },
                            onUseCurrentLocation: _useCurrentLocation,
                            onChangeAddress: () => context.push('/addresses'),
                          ),
                          1 => _StepDateTime(
                            key: const ValueKey(1),
                            dates: _dates,
                            slots: _slots,
                            selectedDate: _selectedDate,
                            selectedSlot: _selectedSlot,
                            onDateSelected: (i) =>
                                setState(() => _selectedDate = i),
                            onSlotSelected: (i) =>
                                setState(() => _selectedSlot = i),
                          ),
                          2 => _StepSummary(
                            key: const ValueKey(2),
                            serviceName: resolvedServiceName,
                            address: _selectedLocationSummary(),
                            date: _dates[_selectedDate],
                            slot: _slots[_selectedSlot],
                            basePrice: resolvedServicePrice,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_paymentVerificationError != null) ...[
                            Text(
                              _paymentVerificationError!,
                              style: tt.bodySmall?.copyWith(color: cs.error),
                              textAlign: TextAlign.center,
                            ),
                            if (!_paymentRecoveryLoadFailed &&
                                _pendingPaymentRecovery != null &&
                                !_paymentVerificationRetryable) ...[
                              TextButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : _dismissResolvedPaymentRecovery,
                                icon: const Icon(Icons.task_alt_rounded),
                                label: const Text(
                                  'Support confirmed this is resolved',
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed:
                                  _isProcessing || _isLoadingPaymentRecovery
                                  ? null
                                  : _paymentVerificationError != null
                                  ? _paymentRecoveryLoadFailed
                                        ? _retryPendingPaymentRecoveryLoad
                                        : _canRetryPaymentVerification
                                        ? _retryPaymentVerification
                                        : _contactSupportForPayment
                                  : () {
                                      if (_step == 0 &&
                                          _selectedAddress == null &&
                                          _selectedGeoPoint == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please select an address or use current location',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      if (_step < 2) {
                                        setState(() => _step++);
                                      } else {
                                        _openCheckout(resolvedServiceId);
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AbzioTheme.buttonRadius,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isProcessing ||
                                      _isLoadingPaymentRecovery) ...[
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Flexible(
                                    child: Text(
                                      _isLoadingPaymentRecovery
                                          ? 'Checking previous payment…'
                                          : _paymentVerificationError != null
                                          ? _paymentRecoveryLoadFailed
                                                ? 'Retry payment check'
                                                : _isProcessing
                                                ? 'Verifying payment…'
                                                : _canRetryPaymentVerification
                                                ? 'Retry verification'
                                                : 'Contact support'
                                          : _step < 2
                                          ? 'Continue'
                                          : _isProcessing
                                          ? _pendingPaymentRecovery
                                                        ?.canVerify ==
                                                    true
                                                ? 'Verifying payment…'
                                                : 'Processing payment…'
                                          : _pendingPaymentRecovery != null
                                          ? 'Contact support'
                                          : 'Proceed to payment',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.titleMedium?.copyWith(
                                        color: cs.onPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (_step < 2 &&
                                      !_isProcessing &&
                                      _paymentVerificationError == null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                            ),
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

// ── Stepper ───────────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = const ['Address', 'Date & Time', 'Summary'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
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
                    ? Icon(Icons.check_rounded, size: 16, color: cs.onPrimary)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: active ? cs.onPrimary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(steps.length, (index) {
            final active = index == currentStep;
            final done = index < currentStep;
            return Expanded(
              child: Text(
                steps[index],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active || done ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Step 0: Address ───────────────────────────────────────────────────────────

class _StepAddress extends ConsumerWidget {
  const _StepAddress({
    super.key,
    required this.selectedAddress,
    required this.hasGeoSelection,
    required this.onAddressSelected,
    required this.onUseCurrentLocation,
    required this.onChangeAddress,
  });
  final SavedAddressItem? selectedAddress;
  final bool hasGeoSelection;
  final ValueChanged<SavedAddressItem> onAddressSelected;
  final Future<void> Function() onUseCurrentLocation;
  final VoidCallback onChangeAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final addressesAsync = ref.watch(savedAddressesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Address',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Where should the professional go?',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        addressesAsync.when(
          data: (addresses) {
            if (addresses.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No saved addresses found. Please add one.',
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/addresses'),
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: const Text('Add address'),
                    ),
                  ],
                ),
              );
            }

            // Auto-select first address if none selected
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (selectedAddress == null &&
                  !hasGeoSelection &&
                  addresses.isNotEmpty) {
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
                          borderRadius: BorderRadius.circular(
                            AbzioTheme.cardRadius,
                          ),
                          border: isSelected
                              ? Border.all(color: cs.primary, width: 2)
                              : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  address.label.toLowerCase() == 'home'
                                      ? Icons.home_rounded
                                      : Icons.location_on_rounded,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  address.label.isNotEmpty
                                      ? address.label
                                      : 'Saved Address',
                                  style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (address.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: cs.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              address.displayAddress,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.5,
                              ),
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
            child: Text(
              'Failed to load addresses.',
              style: tt.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TapScale(
          onTap: () => onUseCurrentLocation(),
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
                Text(
                  'Use current location',
                  style: tt.bodyLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
              border: Border.all(
                color: cs.outlineVariant,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            ),
            child: Row(
              children: [
                Icon(Icons.add_location_alt_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Text(
                  'Add or manage addresses',
                  style: tt.bodyLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        Text(
          'Choose Date',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
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
                    borderRadius: BorderRadius.circular(
                      AbzioTheme.buttonRadius,
                    ),
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
        Text(
          'Choose Time Slot',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
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
                      : Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                        ),
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
    this.couponCode,
    required this.onApplyCoupon,
  });
  final String serviceName;
  final String address;
  final String date;
  final String slot;
  final double basePrice;
  final String? couponCode;
  final VoidCallback onApplyCoupon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Summary',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.cleaning_services_rounded,
                  label: 'Service',
                  value: serviceName,
                ),
                const Divider(height: 24),
                _SummaryRow(
                  icon: Icons.location_on_rounded,
                  label: 'Address',
                  value: address,
                ),
                const Divider(height: 24),
                _SummaryRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: date,
                ),
                const Divider(height: 24),
                _SummaryRow(
                  icon: Icons.access_time_rounded,
                  label: 'Time Slot',
                  value: slot,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Bill Details',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _BillRow(label: 'Service total', amount: basePrice),
                if (couponCode != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Coupon selected: $couponCode',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Eligible coupon savings are confirmed before payment.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _BillRow(
                  label: 'Estimated total',
                  amount: basePrice,
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
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    couponCode != null
                        ? 'Code selected · $couponCode'
                        : 'View offers and coupons',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (couponCode == null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                if (couponCode != null)
                  Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Protected by Veedufix Guarantee',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
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
              Text(
                label,
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
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

String _checkoutErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection problem. Check your internet and try again.';
    }
  }
  return 'Could not start payment. Please try again.';
}
