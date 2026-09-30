import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:share_plus/share_plus.dart';

final bookingInvoiceProvider = FutureProvider.autoDispose
    .family<_BookingInvoice, String>((ref, bookingId) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/bookings/$bookingId/invoice');
      final payload = response['invoice'] ?? response;
      if (payload is! Map<String, dynamic>) {
        throw Exception('Invoice payload missing from response.');
      }
      return _BookingInvoice.fromJson(payload);
    });

class BookingInvoicePage extends ConsumerWidget {
  const BookingInvoicePage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final invoiceAsync = ref.watch(bookingInvoiceProvider(bookingId));

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
          'Invoice',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          invoiceAsync.whenOrNull(
                data: (invoice) => IconButton(
                  tooltip: 'Share invoice summary',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => _shareInvoice(invoice),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => PremiumRetryState(
          icon: Icons.receipt_long_outlined,
          title: 'Could not load invoice',
          subtitle: _invoiceErrorMessage(error),
          onRetry: () => ref.invalidate(bookingInvoiceProvider(bookingId)),
          onRefresh: () async {
            await ref
                .refresh(bookingInvoiceProvider(bookingId).future)
                .then<void>((_) {});
          },
        ),
        data: (invoice) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bookingInvoiceProvider(bookingId));
            await ref.read(bookingInvoiceProvider(bookingId).future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: _InvoiceBody(invoice: invoice),
          ),
        ),
      ),
    );
  }

  Future<void> _shareInvoice(_BookingInvoice invoice) async {
    final lineItems = invoice.lineItems
        .map(
          (item) =>
              '${item.description} × ${item.quantity}\n'
              '  Taxable value: ${_money(item.basePrice)}\n'
              '  GST (${item.gstRate.toStringAsFixed(2)}%): ${_money(item.gstAmount)}\n'
              '  Line total: ${_money(item.total)}',
        )
        .join('\n');
    final text =
        '''
VeeduFix Tax Invoice
Invoice No: ${invoice.invoiceNumber}
Booking Ref: #${invoice.bookingCode.isEmpty ? invoice.bookingId : invoice.bookingCode}
Issued: ${DateFormat('d MMM y').format(invoice.issuedAt.toLocal())}
Business: ${invoice.legalBusinessName}
GSTIN: ${invoice.platformGstin}
${invoice.customerGstin?.trim().isNotEmpty == true ? 'Customer GSTIN: ${invoice.customerGstin}' : ''}
Items:
$lineItems

Subtotal (before discount): ${_money(invoice.subtotalAmount)}
Discount: -${_money(invoice.discountAmount)}
GST: ${_money(invoice.totalGstAmount)}
Grand Total: ${_money(invoice.grandTotal)}
''';
    await Share.share(
      text,
      subject: 'VeeduFix invoice ${invoice.invoiceNumber}',
    );
  }
}

String _invoiceErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final message = data is Map ? data['message']?.toString() : null;
    if (message?.toLowerCase().contains('after payment capture') == true) {
      return 'Your invoice will be available once your payment is confirmed.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Check your internet connection and try again.';
    }
  }
  return 'We could not retrieve this invoice right now. Please try again shortly.';
}

String _bookingStatusLabel(String status) => switch (status.toUpperCase()) {
  'COMPLETED' => 'Completed',
  'IN_PROGRESS' => 'In progress',
  'WORKER_ASSIGNED' => 'Professional assigned',
  'EN_ROUTE' => 'Professional on the way',
  'ARRIVED' => 'Professional arrived',
  'ACCEPTED' => 'Accepted',
  'PENDING' => 'Pending',
  'CANCELLED' || 'CANCELLED_MANUAL' || 'CANCELLED_NO_SHOW' => 'Cancelled',
  'REFUNDED' => 'Refunded',
  _ =>
    status.trim().isEmpty
        ? 'Invoice issued'
        : status.toLowerCase().replaceAll('_', ' '),
};

Color _bookingStatusColor(BuildContext context, String status) =>
    switch (status.toUpperCase()) {
      'COMPLETED' => const Color(0xFF2D7A57),
      'CANCELLED' ||
      'CANCELLED_MANUAL' ||
      'CANCELLED_NO_SHOW' ||
      'REFUNDED' => Theme.of(context).colorScheme.error,
      _ => const Color(0xFFAA7C2F),
    };

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.invoice});

  final _BookingInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1B17),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VeeduFix',
                style: tt.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                invoice.legalBusinessName,
                style: tt.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (invoice.registeredAddress.trim().isNotEmpty)
                Text(
                  invoice.registeredAddress,
                  style: tt.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (invoice.invoiceNumber.trim().isNotEmpty)
                    _HeaderChip(
                      label: 'Invoice #',
                      value: invoice.invoiceNumber,
                    ),
                  _HeaderChip(
                    label: 'Booking',
                    value: invoice.bookingCode.isEmpty
                        ? invoice.bookingId
                        : invoice.bookingCode,
                  ),
                  _HeaderChip(
                    label: 'Issued',
                    value: DateFormat(
                      'd MMM y',
                    ).format(invoice.issuedAt.toLocal()),
                  ),
                  if (invoice.platformGstin.trim().isNotEmpty)
                    _HeaderChip(label: 'GSTIN', value: invoice.platformGstin),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: AbzioTheme.eliteShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bill To',
                style: tt.labelLarge?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                invoice.customerName.trim().isNotEmpty
                    ? invoice.customerName
                    : 'Customer',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _bookingStatusLabel(invoice.bookingStatus),
                style: tt.bodyMedium?.copyWith(
                  color: _bookingStatusColor(context, invoice.bookingStatus),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (invoice.customerGstin?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'GSTIN: ${invoice.customerGstin}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Line Items',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (invoice.lineItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No line items are available for this invoice.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          ...invoice.lineItems.map((item) => _InvoiceLineCard(item: item)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: AbzioTheme.eliteShadow,
          ),
          child: Column(
            children: [
              _SummaryRow(
                label: 'Subtotal',
                value: _money(invoice.subtotalAmount),
              ),
              const SizedBox(height: 8),
              if (invoice.discountAmount > 0) ...[
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'Discount',
                  value: '-${_money(invoice.discountAmount)}',
                ),
              ],
              const SizedBox(height: 8),
              _SummaryRow(label: 'GST', value: _money(invoice.totalGstAmount)),
              const Divider(height: 24),
              _SummaryRow(
                label: 'Grand Total',
                value: _money(invoice.grandTotal),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Text(
            'Prices include applicable GST. See each line item for its tax breakdown.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _InvoiceLineCard extends StatelessWidget {
  const _InvoiceLineCard({required this.item});

  final _InvoiceLineItem item;

  static const _accent = Color(0xFFC2A15E);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.description,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _money(item.total),
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.sacCode.isNotEmpty && item.sacCode != 'PENDING')
                _Tag(label: 'SAC ${item.sacCode}'),
              _Tag(label: 'Qty ${item.quantity}'),
              if (item.gstRate > 0)
                _Tag(label: 'GST ${item.gstRate.toStringAsFixed(2)}%'),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Unit price', value: _money(item.unitPrice)),
          _DetailRow(label: 'Base price', value: _money(item.basePrice)),
          _DetailRow(label: 'GST amount', value: _money(item.gstAmount)),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: emphasize
              ? tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)
              : tt.bodyMedium?.copyWith(color: Colors.black54),
        ),
        Text(
          value,
          style: emphasize
              ? tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFC2A15E),
                )
              : tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium?.copyWith(color: Colors.black54)),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BookingInvoice {
  const _BookingInvoice({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.bookingStatus,
    required this.invoiceNumber,
    required this.issuedAt,
    required this.platformGstin,
    required this.legalBusinessName,
    required this.registeredAddress,
    required this.customerName,
    required this.customerGstin,
    required this.lineItems,
    required this.subtotalAmount,
    required this.totalGstAmount,
    required this.discountAmount,
    required this.grandTotal,
  });

  final String id;
  final String bookingId;
  final String bookingCode;
  final String bookingStatus;
  final String invoiceNumber;
  final DateTime issuedAt;
  final String platformGstin;
  final String legalBusinessName;
  final String registeredAddress;
  final String customerName;
  final String? customerGstin;
  final List<_InvoiceLineItem> lineItems;
  final double subtotalAmount;
  final double totalGstAmount;
  final double discountAmount;
  final double grandTotal;

  factory _BookingInvoice.fromJson(Map<String, dynamic> json) {
    return _BookingInvoice(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      bookingCode: json['bookingCode'] as String? ?? '',
      bookingStatus: json['bookingStatus'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      issuedAt:
          DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
          DateTime.now(),
      platformGstin: json['platformGstin'] as String? ?? '',
      legalBusinessName: json['legalBusinessName'] as String? ?? '',
      registeredAddress: json['registeredAddress'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerGstin: json['customerGstin'] as String?,
      lineItems: (json['lineItems'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_InvoiceLineItem.fromJson)
          .toList(growable: false),
      subtotalAmount: _toDouble(json['subtotalAmount']),
      totalGstAmount: _toDouble(json['totalGstAmount']),
      discountAmount: _toDouble(json['discountAmount']),
      grandTotal: _toDouble(json['grandTotal']),
    );
  }
}

class _InvoiceLineItem {
  const _InvoiceLineItem({
    required this.description,
    required this.sacCode,
    required this.quantity,
    required this.unitPrice,
    required this.basePrice,
    required this.gstRate,
    required this.gstAmount,
    required this.total,
  });

  final String description;
  final String sacCode;
  final int quantity;
  final double unitPrice;
  final double basePrice;
  final double gstRate;
  final double gstAmount;
  final double total;

  factory _InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return _InvoiceLineItem(
      description: json['description'] as String? ?? 'Service',
      sacCode: (json['sacCode'] as String?)?.trim().isNotEmpty == true
          ? json['sacCode'] as String
          : 'PENDING',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: _toDouble(json['unitPrice']),
      basePrice: _toDouble(json['basePrice']),
      gstRate: _toDouble(json['gstRate']),
      gstAmount: _toDouble(json['gstAmount']),
      total: _toDouble(json['total']),
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _money(double value) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}
