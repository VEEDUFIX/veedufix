import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../pages/booking_detail_page.dart';

// ─── Invoice Page ──────────────────────────────────────────────────────────────

class BookingInvoicePage extends ConsumerWidget {
  const BookingInvoicePage({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bookingAsync = ref.watch(bookingDetailPageProvider(bookingId));

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
        title: Text('Invoice', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          bookingAsync.whenOrNull(
                data: (b) => IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => _shareInvoice(context, b),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: PremiumEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Invoice not found',
            subtitle: 'Could not load invoice details.',
          ),
        ),
        data: (booking) => _InvoiceBody(booking: booking),
      ),
    );
  }

  void _shareInvoice(BuildContext context, BookingDetail booking) {
    final text = '''
VeeduFix — Invoice
━━━━━━━━━━━━━━━━━━━━━━━━━
Booking Code:  #${booking.code}
Service:       ${booking.serviceName}
Date:          ${DateFormat('d MMM y').format(booking.scheduledAt)}
Status:        ${booking.status}
${booking.worker != null ? 'Professional:  ${booking.worker!.name}\n' : ''}━━━━━━━━━━━━━━━━━━━━━━━━━
Total Amount:  ₹${booking.totalAmount.toStringAsFixed(2)}
━━━━━━━━━━━━━━━━━━━━━━━━━
Thank you for using VeeduFix!
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice copied to clipboard')),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.booking});
  final BookingDetail booking;

  static const _accent = Color(0xFFC2A15E);
  static const _green = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final subtotal = booking.totalAmount;
    const platformFee = 0.0; // currently no separate fee
    final total = subtotal + platformFee;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          // ─── Invoice card ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
              boxShadow: AbzioTheme.eliteShadow,
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VeeduFix',
                                  style: tt.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Trusted Home Services',
                                  style: tt.bodySmall?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'INVOICE',
                                style: tt.labelSmall?.copyWith(
                                  color: Colors.white60,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '#${booking.code}',
                                style: tt.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _DividerLine(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _HeaderInfo(
                            label: 'Date',
                            value: DateFormat('d MMM y').format(booking.scheduledAt),
                          ),
                          _HeaderInfo(
                            label: 'Time',
                            value: DateFormat('h:mm a').format(booking.scheduledAt),
                            align: TextAlign.right,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      _StatusBadge(status: booking.status),
                      const SizedBox(height: 20),

                      // Service details
                      const _InvoiceSection(label: 'Service Details'),
                      const SizedBox(height: 12),
                      _LineItem(
                        description: booking.serviceName,
                        amount: '₹${subtotal.toStringAsFixed(2)}',
                        isBold: false,
                      ),
                      if (booking.addressLabel != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                booking.addressLabel!,
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Worker
                      if (booking.worker != null) ...[
                        const SizedBox(height: 16),
                        const _InvoiceSection(label: 'Professional'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            MarketplaceNetworkAvatar(
                              imageUrl: booking.worker!.avatarUrl,
                              radius: 18,
                              backgroundColor: _accent.withValues(alpha: 0.15),
                              fallback: Text(
                                booking.worker!.name.substring(0, 1).toUpperCase(),
                                style: tt.labelMedium?.copyWith(
                                  color: _accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.worker!.name,
                                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 3),
                                    Text(
                                      booking.worker!.rating.toStringAsFixed(1),
                                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 16),

                      // Payment breakdown
                      const _InvoiceSection(label: 'Payment Breakdown'),
                      const SizedBox(height: 12),
                      _LineItem(description: 'Service fee', amount: '₹${subtotal.toStringAsFixed(2)}'),
                      const SizedBox(height: 6),
                      const _LineItem(description: 'Platform fee', amount: '₹0.00'),
                      const SizedBox(height: 6),
                      const _LineItem(description: 'Taxes & GST', amount: 'Included'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _green.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Paid',
                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '₹${total.toStringAsFixed(2)}',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: _green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Thank you for using VeeduFix!',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'For support, contact us at support@veedufix.com',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: TapScale(
                  onTap: () => _shareInvoice(context, booking),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded, size: 16, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Copy Invoice',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareInvoice(BuildContext context, BookingDetail b) {
    final text = '''
VeeduFix — Invoice
━━━━━━━━━━━━━━━━━━━━━━━━━
Booking:  #${b.code}
Service:  ${b.serviceName}
Date:     ${DateFormat('d MMM y').format(b.scheduledAt)}
${b.worker != null ? 'By:       ${b.worker!.name}\n' : ''}━━━━━━━━━━━━━━━━━━━━━━━━━
Total:    ₹${b.totalAmount.toStringAsFixed(2)}
━━━━━━━━━━━━━━━━━━━━━━━━━''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice copied to clipboard')),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.2),
      );
}

class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({required this.label, required this.value, this.align = TextAlign.left});
  final String label;
  final String value;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.labelSmall?.copyWith(color: Colors.white60, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: tt.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            textAlign: align),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color => switch (status) {
        'COMPLETED' => const Color(0xFF10B981),
        'CANCELLED' || 'REFUNDED' => const Color(0xFFEF4444),
        'IN_PROGRESS' => const Color(0xFF6366F1),
        _ => const Color(0xFFF59E0B),
      };

  String get _label => switch (status) {
        'COMPLETED' => 'Payment Successful',
        'CANCELLED' => 'Booking Cancelled',
        'REFUNDED' => 'Refunded',
        'IN_PROGRESS' => 'Work in Progress',
        _ => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceSection extends StatelessWidget {
  const _InvoiceSection({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.description, required this.amount, this.isBold = false});
  final String description;
  final String amount;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            description,
            style: isBold
                ? tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                : tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Text(
          amount,
          style: isBold
              ? tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
              : tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
