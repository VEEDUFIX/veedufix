import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../domain/entities/worker_wallet.dart';
import '../providers/worker_wallet_providers.dart';
import '../../../profile/presentation/providers/worker_profile_providers.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────

class WorkerWalletPage extends ConsumerWidget {
  const WorkerWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final walletAsync = ref.watch(workerWalletProvider);
    final profileAsync = ref.watch(workerAccountProfileProvider);

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
        loading: () => const _WalletLoadingView(),
        error: (_, __) => Center(
          child: PremiumEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Could not load wallet',
            subtitle: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(workerWalletProvider),
          ),
        ),
        data: (wallet) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(workerWalletProvider.future);
            await ref.read(workerAccountProfileProvider.future);
          },
          child: _WalletBody(wallet: wallet, profileAsync: profileAsync),
        ),
      ),
    );
  }
}

class _WalletBody extends ConsumerWidget {
  const _WalletBody({required this.wallet, required this.profileAsync});
  final WorkerWallet wallet;
  final AsyncValue<Map<String, dynamic>> profileAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final payoutUpiId = _extractPayoutUpi(profileAsync.valueOrNull);
    final hasPayoutDetails = payoutUpiId != null;

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
              const SizedBox(height: 14),
              Text(
                'Withdrawals start at ₹100 and are usually processed within 24 hours.',
                style: tt.bodySmall?.copyWith(color: Colors.white70, height: 1.3),
              ),
              const SizedBox(height: 10),
              Text(
                hasPayoutDetails
                    ? 'Payouts will be sent to your saved UPI: $payoutUpiId'
                    : 'Add a payout UPI in your profile before requesting withdrawals.',
                style: tt.bodySmall?.copyWith(color: Colors.white70, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Withdraw CTA ─────────────────────────────────────────────────
        TapScale(
          onTap: hasPayoutDetails
              ? () => _showPayoutSheet(context, ref, wallet.balance, payoutUpiId)
              : () => context.push('/profile/edit'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: hasPayoutDetails ? cs.primaryContainer.withValues(alpha: 0.4) : cs.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              border: Border.all(color: hasPayoutDetails ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasPayoutDetails ? Icons.payments_rounded : Icons.person_rounded,
                  color: hasPayoutDetails ? cs.primary : cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  hasPayoutDetails ? 'Request payout' : 'Add payout details',
                  style: tt.titleSmall?.copyWith(
                    color: hasPayoutDetails ? cs.primary : cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          hasPayoutDetails
              ? 'Use the wallet sheet below to request a payout against your saved UPI.'
              : 'Open your profile to add a payout UPI, then return here to request a withdrawal.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

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

  void _showPayoutSheet(BuildContext context, WidgetRef ref, double balance, String? payoutUpiId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayoutSheet(
        availableBalance: balance,
        ref: ref,
        payoutUpiId: payoutUpiId,
      ),
    );
  }

  Future<void> _exportStatement(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(workerWalletRepositoryProvider);
      final bytes = await repo.exportStatement();
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
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not export statement.')),
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
  const _PayoutSheet({
    required this.availableBalance,
    required this.ref,
    required this.payoutUpiId,
  });
  final double availableBalance;
  final WidgetRef ref;
  final String? payoutUpiId;

  @override
  ConsumerState<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends ConsumerState<_PayoutSheet> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const _presetAmounts = [100.0, 500.0, 1000.0];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final payoutState = ref.watch(payoutRequestProvider);
    final isLoading = payoutState.isLoading;
    final presetAmounts = _eligiblePresetAmounts();
    final showFullBalanceChip = widget.availableBalance >= 100 &&
        !presetAmounts.any((amount) => amount == widget.availableBalance);

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
              if (widget.availableBalance < 100) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: cs.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You need at least ₹100 to request a payout. Keep earning and come back once your balance crosses the threshold.',
                          style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payout destination', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      widget.payoutUpiId ?? 'No UPI saved yet',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.payoutUpiId != null
                          ? 'This request will be sent to the UPI saved in your profile.'
                          : 'Add a UPI in your profile before you can request a payout.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                    ),
                    if (widget.payoutUpiId == null) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => context.push('/profile/edit'),
                        child: const Text('Open profile'),
                      ),
                    ],
                  ],
                ),
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
                textInputAction: TextInputAction.done,
                validator: (v) {
                  final amount = double.tryParse(v ?? '');
                  if (amount == null || amount <= 0) { return 'Enter a valid amount'; }
                  if (amount > widget.availableBalance) { return 'Insufficient balance'; }
                  if (amount < 100) { return 'Minimum withdrawal is ₹100'; }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Minimum withdrawal is ₹100. Higher amounts will process in the same payout queue.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final amount in presetAmounts)
                    ActionChip(
                      label: Text('₹${_formatPresetAmount(amount)}'),
                      onPressed: () => _setAmount(amount),
                      labelStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  if (showFullBalanceChip)
                    ActionChip(
                      label: const Text('Full balance'),
                      onPressed: () => _setAmount(widget.availableBalance),
                      labelStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                ],
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
                      : Text('Request payout', style: tt.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We’ll queue this request for approval and processing.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<double> _eligiblePresetAmounts() {
    return _presetAmounts
        .where((amount) => amount <= widget.availableBalance && amount >= 100)
        .toList(growable: false);
  }

  String _formatPresetAmount(double amount) {
    return amount == amount.truncateToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  void _setAmount(double amount) {
    final formatted = amount == amount.truncateToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    _amountController.text = formatted;
    _amountController.selection = TextSelection.collapsed(offset: formatted.length);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) { return; }
    final amount = double.parse(_amountController.text);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(payoutRequestProvider.notifier).requestPayout(amount, upiId: widget.payoutUpiId);
    if (!mounted) { return; }
    final error = ref.read(payoutRequestProvider).error;
    if (error != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Payout request could not be submitted.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Payout request submitted! Usually processed in 24h.')),
      );
    }
  }
}

String? _extractPayoutUpi(Map<String, dynamic>? accountData) {
  if (accountData == null) return null;
  final user = accountData['user'] as Map<String, dynamic>?;
  final workerProfile = user?['workerProfile'] as Map<String, dynamic>?;
  final upi = workerProfile?['upiId'] as String?;
  final trimmed = upi?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

class _WalletLoadingView extends StatelessWidget {
  const _WalletLoadingView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget block({double height = 16, double width = double.infinity}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(height: 14, width: 120),
                const SizedBox(height: 14),
                block(height: 44, width: 180),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: block(height: 56)),
                    const SizedBox(width: 12),
                    Expanded(child: block(height: 56)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                block(height: 18, width: 160),
                const SizedBox(height: 14),
                for (var i = 0; i < 3; i++) ...[
                  block(height: 72),
                  if (i < 2) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
