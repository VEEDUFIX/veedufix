import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class CartItem {
  final CatalogService service;
  final int quantity;
  final String? variantId;
  final List<String> addonIds;

  CartItem({
    required this.service,
    this.quantity = 1,
    this.variantId,
    this.addonIds = const [],
  });

  CartItem copyWith({
    CatalogService? service,
    int? quantity,
    String? variantId,
    bool clearVariant = false,
    List<String>? addonIds,
  }) {
    return CartItem(
      service: service ?? this.service,
      quantity: quantity ?? this.quantity,
      variantId: clearVariant ? null : variantId ?? this.variantId,
      addonIds: addonIds ?? this.addonIds,
    );
  }

  double get unitPrice {
    CatalogServiceVariant? selectedVariant;
    for (final variant in service.variants) {
      if (variant.id == variantId) {
        selectedVariant = variant;
        break;
      }
    }
    final base =
        selectedVariant?.price ??
        (service.variants.isEmpty
            ? service.startingPrice
            : service.variants
                  .map((variant) => variant.price)
                  .reduce((a, b) => a < b ? a : b));
    return base +
        service.addons
            .where((addon) => addonIds.contains(addon.id))
            .fold<double>(0, (sum, addon) => sum + addon.price);
  }

  bool get hasRequiredVariant =>
      service.variants.isEmpty ||
      service.variants.any((v) => v.id == variantId);

  String get configurationLabel {
    CatalogServiceVariant? selectedVariant;
    for (final variant in service.variants) {
      if (variant.id == variantId) {
        selectedVariant = variant;
        break;
      }
    }
    return [
      if (selectedVariant != null) selectedVariant.name,
      ...service.addons
          .where((addon) => addonIds.contains(addon.id))
          .map((addon) => addon.name),
    ].join(' · ');
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addService(CatalogService service) {
    final index = state.indexWhere((item) => item.service.id == service.id);
    if (index >= 0) {
      final updated = List<CartItem>.from(state);
      updated[index] = updated[index].copyWith(
        quantity: updated[index].quantity + 1,
      );
      state = updated;
    } else {
      state = [...state, CartItem(service: service)];
    }
  }

  void removeService(String serviceId) {
    final index = state.indexWhere((item) => item.service.id == serviceId);
    if (index >= 0) {
      final currentQuantity = state[index].quantity;
      if (currentQuantity > 1) {
        final updated = List<CartItem>.from(state);
        updated[index] = updated[index].copyWith(quantity: currentQuantity - 1);
        state = updated;
      } else {
        state = state.where((item) => item.service.id != serviceId).toList();
      }
    }
  }

  void configureService(
    String serviceId, {
    String? variantId,
    List<String>? addonIds,
  }) {
    final index = state.indexWhere((item) => item.service.id == serviceId);
    if (index < 0) return;
    final updated = List<CartItem>.from(state);
    updated[index] = updated[index].copyWith(
      variantId: variantId,
      clearVariant: variantId == null,
      addonIds: addonIds,
    );
    state = updated;
  }

  void clearCart() {
    state = [];
  }

  double get totalPrice {
    return state.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
