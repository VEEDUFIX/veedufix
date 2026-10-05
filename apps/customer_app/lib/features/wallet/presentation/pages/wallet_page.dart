import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          'My Wallet',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: walletState.when(
        data: (wallet) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(walletProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _BalanceHeroCard(balance: wallet.balance),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push('/referral'),
                        icon: const Icon(Icons.people_alt_rounded),
                        label: const Text('Referrals'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/support?autoCompose=true&category=payment&subject=${Uri.encodeComponent('Wallet or payment help')}&message=${Uri.encodeComponent('I need help with my wallet balance, credits, or a payment issue.')}',
                        ),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('Support'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const PremiumSectionHeader(
                  title: 'Transaction history',
                  subtitle: 'Wallet credits and charges from your bookings.',
                ),
                const SizedBox(height: 12),
                if (wallet.transactions.isEmpty)
                  const PremiumEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No transactions yet',
                    subtitle:
                        'Your wallet credits and debits will appear here.',
                  )
                else
                  ...wallet.transactions.map(
                    (tx) => _TransactionCard(transaction: tx),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => PremiumRetryState(
          title: 'Could not load wallet',
          subtitle: 'Check your connection and try again.',
          icon: Icons.account_balance_wallet_outlined,
          onRetry: () => ref.invalidate(walletProvider),
          onRefresh: () async {
            await ref.refresh(walletProvider.future).then<void>((_) {});
          },
        ),
      ),
    );
  }
}

class _BalanceHeroCard extends StatelessWidget {
  const _BalanceHeroCard({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            AbzioTheme.lightMuted,
          ],
        ),
        border: Border.all(color: AbzioTheme.lightBorder.withValues(alpha: 0.8)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'AVAILABLE BALANCE',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: textTheme.headlineLarge?.copyWith(
              fontFamily: 'Outfit',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your current Veedufix wallet balance',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final WalletTransaction transaction;

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day =
        '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
    return date.year == DateTime.now().year ? day : '$day ${date.year}';
  }

  String _formatReference(String reference) {
    if (reference.trim().isEmpty) return 'Wallet transaction';
    return reference
        .toLowerCase()
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final type = transaction.type.toUpperCase();
    final isDebit = type.contains('DEBIT') || type == 'PAYOUT_PENDING';
    final isCredit = !isDebit && transaction.amount >= 0;
    final amount = transaction.amount.abs();
    final amountColor = isCredit
        ? AbzioTheme.successColor
        : AbzioTheme.dangerColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCredit
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: amountColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatReference(transaction.referenceType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(transaction.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
