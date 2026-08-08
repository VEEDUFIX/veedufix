class WorkerWalletTransaction {
  const WorkerWalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String type;
  final double amount;
  final double balanceAfter;
  final DateTime createdAt;
  final String? note;

  bool get isCredit => amount >= 0;

  String get label => switch (type) {
        'CREDIT' => 'Job Earnings',
        'DEBIT' => 'Deduction',
        'PAYOUT' => 'Payout Withdrawn',
        'BONUS' => 'Bonus',
        'REFERRAL_BONUS' => 'Referral Bonus',
        _ => type.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
      };

  factory WorkerWalletTransaction.fromJson(Map<String, dynamic> json) =>
      WorkerWalletTransaction(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'CREDIT',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        note: json['note'] as String?,
      );
}

class WorkerWallet {
  const WorkerWallet({
    required this.balance,
    required this.totalEarnings,
    required this.pendingPayout,
    required this.transactions,
  });

  final double balance;
  final double totalEarnings;
  final double pendingPayout;
  final List<WorkerWalletTransaction> transactions;

  factory WorkerWallet.fromJson(Map<String, dynamic> json) => WorkerWallet(
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
        pendingPayout: (json['pendingPayout'] as num?)?.toDouble() ?? 0.0,
        transactions: (json['transactions'] as List<dynamic>? ?? [])
            .map((t) => WorkerWalletTransaction.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
