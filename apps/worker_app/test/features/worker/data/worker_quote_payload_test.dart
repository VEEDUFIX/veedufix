import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/worker/domain/entities/job_execution.dart';

void main() {
  test(
      'Partner quote serializes itemized amounts using backend qty/unitPrice keys',
      () {
    const quote = QuotePayload(
      amount: 420,
      notes: 'Labor and materials',
      itemized: [
        QuoteItem(label: 'Labor', qty: 2, unitPrice: 150),
        QuoteItem(label: 'Materials', qty: 1, unitPrice: 120),
      ],
    );

    expect(quote.toJson(), {
      'amount': 420,
      'notes': 'Labor and materials',
      'itemized': [
        {'label': 'Labor', 'qty': 2, 'unitPrice': 150},
        {'label': 'Materials', 'qty': 1, 'unitPrice': 120},
      ],
    });
  });
}
