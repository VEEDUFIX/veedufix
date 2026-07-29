class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.referenceType,
    required this.createdAt,
    this.referenceId,
  });

  final String id;
  final String type; // CREDIT or DEBIT
  final double amount;
  final String referenceType;
  final String? referenceId;
  final DateTime createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'CREDIT',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      referenceType: json['referenceType'] as String? ?? '',
      referenceId: json['referenceId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class WalletDetails {
  const WalletDetails({
    required this.balance,
    required this.referralCode,
    required this.totalReferrals,
    required this.referralEarnings,
    required this.transactions,
  });

  final double balance;
  final String referralCode;
  final int totalReferrals;
  final double referralEarnings;
  final List<WalletTransaction> transactions;

  factory WalletDetails.fromJson(Map<String, dynamic> json) {
    final txList = (json['transactions'] as List<dynamic>? ?? []);
    return WalletDetails(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      referralCode: json['referralCode'] as String? ?? '',
      totalReferrals: (json['totalReferrals'] as num?)?.toInt() ?? 0,
      referralEarnings: (json['referralEarnings'] as num?)?.toDouble() ?? 0.0,
      transactions: txList
          .whereType<Map<String, dynamic>>()
          .map(WalletTransaction.fromJson)
          .toList(growable: false),
    );
  }
}
