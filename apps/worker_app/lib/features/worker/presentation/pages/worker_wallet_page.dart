import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

// ─── Entities ─────────────────────────────────────────────────────────────────

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

// ─── Provider ─────────────────────────────────────────────────────────────────

final workerWalletProvider = FutureProvider.autoDispose<WorkerWallet>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/worker/wallet');
  return WorkerWallet.fromJson(data);
});

final payoutRequestProvider = StateNotifierProvider<_PayoutNotifier, AsyncValue<void>>((ref) {
  return _PayoutNotifier(ref);
});

class _PayoutNotifier extends StateNotifier<AsyncValue<void>> {
  _PayoutNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> requestPayout(double amount, String upiId) async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      await api.post('/users/worker/wallet/payout', data: {'amount': amount, 'upiId': upiId});
      state = const AsyncValue.data(null);
      _ref.invalidate(workerWalletProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class WorkerWalletPage extends ConsumerWidget {
  const WorkerWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final walletAsync = ref.watch(workerWalletProvider);

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
        title: Text('Wallet & Earnings', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: PremiumEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Could not load wallet',
            subtitle: 'Pull down to retry.',
          ),
        ),
        data: (wallet) => RefreshIndicator(
          onRefresh: () => ref.refresh(workerWalletProvider.future),
          child: _WalletBody(wallet: wallet),
        ),
      ),
    );
  }
}

class _WalletBody extends ConsumerWidget {
  const _WalletBody({required this.wallet});
  final WorkerWallet wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // ── Balance hero card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF0F766E), cs.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            boxShadow: AbzioTheme.eliteShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text('Available Balance', style: tt.labelMedium?.copyWith(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '₹${wallet.balance.toStringAsFixed(2)}',
                style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _StatChip(label: 'Total Earned', value: '₹${wallet.totalEarnings.toStringAsFixed(0)}'),
                  const SizedBox(width: 12),
                  _StatChip(label: 'Pending', value: '₹${wallet.pendingPayout.toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Withdraw CTA ─────────────────────────────────────────────────
        TapScale(
          onTap: () => _showPayoutSheet(context, ref, wallet.balance),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Withdraw to UPI',
                  style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Transaction history ──────────────────────────────────────────
        TapScale(
          onTap: () => _exportStatement(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, color: cs.onSurfaceVariant, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Export statement CSV',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Transaction History', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        if (wallet.transactions.isEmpty)
          const PremiumEmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No transactions yet',
            subtitle: 'Your earnings will appear here after completing jobs.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: wallet.transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final tx = wallet.transactions[index];
              return _TxCard(tx: tx);
            },
          ),
      ],
    );
  }

  void _showPayoutSheet(BuildContext context, WidgetRef ref, double balance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayoutSheet(availableBalance: balance, ref: ref),
    );
  }

  Future<void> _exportStatement(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ref.read(apiClientProvider).dio.get<List<int>>(
        '/worker/earnings/export/csv',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data ?? const <int>[];
      if (bytes.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Statement export is empty right now.')),
        );
        return;
      }

      final csv = utf8.decode(bytes);
      await Clipboard.setData(ClipboardData(text: csv));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Statement exported'),
          content: const Text('The CSV has been copied to your clipboard.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export statement: $e')),
      );
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  const _TxCard({required this.tx});
  final WorkerWalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isCredit = tx.isCredit;
    final color = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return TapScale(
      onTap: () => _showTransactionDetails(context, tx),
      child: PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.label, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM y, h:mm a').format(tx.createdAt),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : ''}₹${tx.amount.abs().toStringAsFixed(2)}',
                    style: tt.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bal: ₹${tx.balanceAfter.toStringAsFixed(2)}',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showTransactionDetails(BuildContext context, WorkerWalletTransaction tx) {
  final amountColor = tx.isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      final tt = Theme.of(sheetContext).textTheme;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    ),
                    child: Icon(
                      tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.label, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d MMM y, h:mm a').format(tx.createdAt),
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Transaction ID', value: tx.id),
              _DetailRow(label: 'Amount', value: '${tx.isCredit ? '+' : '-'}₹${tx.amount.abs().toStringAsFixed(2)}'),
              _DetailRow(label: 'Balance after', value: '₹${tx.balanceAfter.toStringAsFixed(2)}'),
              if (tx.note != null && tx.note!.trim().isNotEmpty) _DetailRow(label: 'Note', value: tx.note!.trim()),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: tx.id));
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Transaction ID copied')),
                      );
                    }
                  },
                  child: const Text('Copy transaction ID'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ─── Payout bottom sheet ──────────────────────────────────────────────────────

class _PayoutSheet extends ConsumerStatefulWidget {
  const _PayoutSheet({required this.availableBalance, required this.ref});
  final double availableBalance;
  final WidgetRef ref;

  @override
  ConsumerState<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends ConsumerState<_PayoutSheet> {
  final _upiController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _upiController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final payoutState = ref.watch(payoutRequestProvider);
    final isLoading = payoutState.isLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Withdraw Earnings', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Available: ₹${widget.availableBalance.toStringAsFixed(2)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _upiController,
                decoration: InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'yourname@upi',
                  prefixIcon: const Icon(Icons.account_balance_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) { return 'Enter your UPI ID'; }
                  if (!v.contains('@')) { return 'Enter a valid UPI ID'; }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: '500',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final amount = double.tryParse(v ?? '');
                  if (amount == null || amount <= 0) { return 'Enter a valid amount'; }
                  if (amount > widget.availableBalance) { return 'Insufficient balance'; }
                  if (amount < 100) { return 'Minimum withdrawal is ₹100'; }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Withdraw Now', style: tt.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) { return; }
    final amount = double.parse(_amountController.text);
    final upiId = _upiController.text.trim();
    await ref.read(payoutRequestProvider.notifier).requestPayout(amount, upiId);
    if (!mounted) { return; }
    final error = ref.read(payoutRequestProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $error'), backgroundColor: Colors.red),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request submitted! Usually processed in 24h.')),
      );
    }
  }
}
