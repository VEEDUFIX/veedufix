class SparePartItem {
  const SparePartItem({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount': amount,
      };
}

class SparePartsPayload {
  const SparePartsPayload({
    required this.items,
    this.receiptPhotoUrl,
  });

  final List<SparePartItem> items;
  final String? receiptPhotoUrl;

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
      };
}

class QuoteItem {
  const QuoteItem({
    required this.label,
    required this.qty,
    required this.unitPrice,
  });

  final String label;
  final int qty;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
        'label': label,
        'qty': qty,
        'unitPrice': unitPrice,
      };
}

class QuotePayload {
  const QuotePayload({
    required this.amount,
    required this.itemized,
    this.notes,
  });

  final double amount;
  final List<QuoteItem> itemized;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'itemized': itemized.map((i) => i.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };
}
