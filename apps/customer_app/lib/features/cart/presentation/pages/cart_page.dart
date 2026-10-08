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
    final optionsConfigured = cartItems.every(
      (item) => item.hasRequiredVariant,
    );
    final itemCount = cartItems.fold<int>(
      0,
      (count, item) => count + item.quantity,
    );

    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
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
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: cs.primary.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a service to get started.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/search'),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Browse services'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                ...cartItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _CartItemTile(item: item),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order estimate',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Items', style: tt.bodyMedium),
                          Text('$itemCount', style: tt.bodyMedium),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated subtotal',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Any applicable taxes or fees are confirmed before payment.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: cartItems.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: optionsConfigured
                        ? () => context.push('/checkout')
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              optionsConfigured
                                  ? 'Continue · ₹${total.toStringAsFixed(2)}'
                                  : 'Choose an option to continue',
                              style: tt.titleSmall?.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                ),
                child: item.service.images.isEmpty
                    ? Icon(Icons.design_services_rounded, color: cs.primary)
                    : Image.network(
                        item.service.images.first.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.design_services_rounded,
                          color: cs.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.service.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '₹${item.unitPrice.toStringAsFixed(2)} each',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (item.service.variants.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(
                'cart-variant-${item.service.id}-${item.variantId ?? 'unselected'}',
              ),
              initialValue: item.variantId,
              decoration: const InputDecoration(
                labelText: 'Choose an option',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: item.service.variants
                  .map(
                    (variant) => DropdownMenuItem<String>(
                      value: variant.id,
                      child: Text(
                        '${variant.name} · ₹${variant.price.toStringAsFixed(2)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (variantId) => ref
                  .read(cartProvider.notifier)
                  .configureService(item.service.id, variantId: variantId),
            ),
            const SizedBox(height: 10),
          ],
          if (item.service.addons.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Optional add-ons',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ...item.service.addons.map(
              (addon) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.addonIds.contains(addon.id),
                title: Text(addon.name),
                subtitle: (addon.description ?? '').trim().isEmpty
                    ? null
                    : Text(addon.description!.trim()),
                secondary: Text('+ ₹${addon.price.toStringAsFixed(2)}'),
                onChanged: (selected) {
                  final nextIds = List<String>.from(item.addonIds);
                  if (selected ?? false) {
                    if (!nextIds.contains(addon.id)) nextIds.add(addon.id);
                  } else {
                    nextIds.remove(addon.id);
                  }
                  ref
                      .read(cartProvider.notifier)
                      .configureService(
                        item.service.id,
                        variantId: item.variantId,
                        addonIds: nextIds,
                      );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item total',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                      style: tt.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Remove one ${item.service.name}',
                      onPressed: () => ref
                          .read(cartProvider.notifier)
                          .removeService(item.service.id),
                      icon: const Icon(Icons.remove_rounded, size: 20),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                    Semantics(
                      label: '${item.quantity} ${item.service.name} in cart',
                      child: Text(
                        '${item.quantity}',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add one ${item.service.name}',
                      onPressed: () => ref
                          .read(cartProvider.notifier)
                          .addService(item.service),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
