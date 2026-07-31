import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/cart_providers.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = ref.read(cartProvider.notifier).totalPrice;
    final tax = total * 0.18; // 18% GST

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: cs.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('Your cart is empty', style: tt.titleLarge),
                  const SizedBox(height: 8),
                  Text('Add services to get started', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ...cartItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _CartItemTile(item: item),
                    )),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Summary', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Item Total', style: tt.bodyMedium),
                          Text('₹${total.toStringAsFixed(0)}', style: tt.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Taxes & Fee (18%)', style: tt.bodyMedium),
                          Text('₹${tax.toStringAsFixed(2)}', style: tt.bodyMedium),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('₹${(total + tax).toStringAsFixed(2)}', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: cartItems.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.paddingOf(context).bottom + 16),
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: TapScale(
                onTap: () {
                  context.push('/checkout'); // Push to checkout
                },
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Proceed to Checkout',
                      style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            ),
            child: Icon(Icons.design_services_rounded, color: cs.primary), // Fallback icon
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.service.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('₹${item.service.startingPrice}', style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                TapScale(
                  onTap: () => ref.read(cartProvider.notifier).removeService(item.service.id),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.remove, size: 20),
                  ),
                ),
                Text('${item.quantity}', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                TapScale(
                  onTap: () => ref.read(cartProvider.notifier).addService(item.service),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.add, size: 20),
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
