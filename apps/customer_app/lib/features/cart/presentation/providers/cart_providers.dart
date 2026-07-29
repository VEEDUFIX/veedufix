import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class CartItem {
  final CatalogService service;
  final int quantity;

  CartItem({required this.service, this.quantity = 1});

  CartItem copyWith({CatalogService? service, int? quantity}) {
    return CartItem(
      service: service ?? this.service,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addService(CatalogService service) {
    final index = state.indexWhere((item) => item.service.id == service.id);
    if (index >= 0) {
      final updated = List<CartItem>.from(state);
      updated[index] = updated[index].copyWith(quantity: updated[index].quantity + 1);
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

  void clearCart() {
    state = [];
  }

  double get totalPrice {
    return state.fold(0, (sum, item) => sum + (item.service.startingPrice * item.quantity));
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
