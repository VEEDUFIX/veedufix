import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class OffersPage extends ConsumerWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final offersAsync = ref.watch(couponsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers & Coupons'),
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: cs.surface,
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(couponsProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.72,
                    child: const Center(
                      child: PremiumEmptyState(
                        icon: Icons.local_offer_outlined,
                        title: 'No offers available',
                        subtitle: 'New offers will appear here when available.',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(couponsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: offers.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${offers.length} current ${offers.length == 1 ? 'offer' : 'offers'}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return _CouponCard(offer: offers[index - 1]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => PremiumRetryState(
          title: 'Something went wrong',
          subtitle: 'Check your connection and try again.',
          icon: Icons.error_outline,
          onRetry: () => ref.invalidate(couponsProvider),
          onRefresh: () async {
            await ref.refresh(couponsProvider.future).then<void>((_) {});
          },
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.offer});
  final CouponModel offer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: AbzioTheme.shadowFor(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_offer_rounded, color: accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          offer.discountLabel,
                          style: tt.labelLarge?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (offer.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          offer.description,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _OfferDetail(label: offer.expiryLabel),
                          if (offer.minOrderAmount != null &&
                              offer.minOrderAmount! > 0)
                            _OfferDetail(
                              label:
                                  'Min. order ₹${offer.minOrderAmount!.toStringAsFixed(0)}',
                            ),
                          if (offer.maxDiscountAmount != null &&
                              offer.discountType.toUpperCase() == 'PERCENTAGE')
                            _OfferDetail(
                              label:
                                  'Up to ₹${offer.maxDiscountAmount!.toStringAsFixed(0)} off',
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.65),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                offer.code.trim().isEmpty
                                    ? 'CODE UNAVAILABLE'
                                    : offer.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelLarge?.copyWith(
                                  color: cs.onSurface,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy offer code',
                              visualDensity: VisualDensity.compact,
                              onPressed: offer.code.trim().isEmpty
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: offer.code),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text('Offer code copied'),
                                          ),
                                        );
                                    },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: offer.code.trim().isEmpty
                              ? null
                              : () => context.pop(offer.code),
                          child: const Text('Use this offer'),
                        ),
                      ),
                    ],
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

class _OfferDetail extends StatelessWidget {
  const _OfferDetail({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
