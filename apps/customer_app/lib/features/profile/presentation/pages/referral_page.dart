import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:share_plus/share_plus.dart';

class ReferralPage extends ConsumerWidget {
  const ReferralPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final walletAsync = ref.watch(walletProvider);

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
                color: cs.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text(
          'Wallet & Referrals',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => PremiumRetryState(
          icon: Icons.wallet_rounded,
          title: 'Could not load wallet',
          subtitle: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(walletProvider),
          onRefresh: () async {
            await ref.refresh(walletProvider.future).then<void>((_) {});
          },
        ),
        data: (wallet) {
          final referralCode = wallet.referralCode.trim();
          final hasReferralCode = referralCode.isNotEmpty;
          final reward = '₹${wallet.referralRewardAmount.toStringAsFixed(2)}';
          final hasReferralLimit = wallet.referralMaxSuccessfulPerReferrer > 0;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(walletProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ─── Wallet balance card ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet Balance',
                        style: tt.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${wallet.balance.toStringAsFixed(2)}',
                        style: tt.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${wallet.totalReferrals}${hasReferralLimit ? ' / ${wallet.referralMaxSuccessfulPerReferrer}' : ''} referrals · ₹${wallet.referralEarnings.toStringAsFixed(0)} earned',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Referral code card ─────────────────────────────────────
                PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),

                    child: Column(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: cs.primary,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your Referral Code',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          !wallet.referralsEnabled
                              ? 'Referral rewards are temporarily unavailable.'
                              : hasReferralLimit
                                  ? 'You and your friend each receive $reward in wallet credit. Rewards are limited to ${wallet.referralMaxSuccessfulPerReferrer} successful referrals per account.'
                                  : 'You and your friend each receive $reward in wallet credit when they sign up with your code.',
                          textAlign: TextAlign.center,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(
                              AbzioTheme.buttonRadius,
                            ),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  hasReferralCode
                                      ? referralCode
                                      : 'Code unavailable',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy referral code',
                          onPressed: hasReferralCode && wallet.referralsEnabled
                                    ? () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: referralCode),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Referral code copied!',
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.copy_rounded,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: hasReferralCode && wallet.referralsEnabled
                                ? () {
                                    Share.share(
                                      'Join me on Veedufix for home services. Sign up with my referral code $referralCode. We both receive $reward wallet credit when the code is accepted.',
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Share with Friends'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ─── How it works ───────────────────────────────────────────
                Text(
                  'How it works',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                PremiumCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildStep(
                          context,
                          '1',
                          'Share your code with friends',
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 20,
                              child: VerticalDivider(thickness: 2),
                            ),
                          ),
                        ),
                        _buildStep(
                          context,
                          '2',
                          'Friend signs up with your code',
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 20,
                              child: VerticalDivider(thickness: 2),
                            ),
                          ),
                        ),
                        _buildStep(
                          context,
                          '3',
                          wallet.referralsEnabled
                              ? 'Both receive $reward wallet credit'
                              : 'Referral rewards are currently paused',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Transaction history ────────────────────────────────────
                Text(
                  'Transaction History',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (wallet.transactions.isEmpty)
                  const PremiumEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No transactions yet',
                    subtitle: 'Your wallet activity will appear here.',
                  )
                else
                  ...wallet.transactions.map(
                    (tx) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: tx.amount >= 0
                                      ? const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.1)
                                      : cs.errorContainer.withValues(
                                          alpha: 0.3,
                                        ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  tx.amount >= 0
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: tx.amount >= 0
                                      ? const Color(0xFF10B981)
                                      : cs.error,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.referenceType
                                          .replaceAll('_', ' ')
                                          .toLowerCase()
                                          .split(' ')
                                          .map(
                                            (w) => w.isNotEmpty
                                                ? '${w[0].toUpperCase()}${w.substring(1)}'
                                                : w,
                                          )
                                          .join(' '),
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(tx.createdAt),
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${tx.amount >= 0 ? '+' : '-'}₹${tx.amount.abs().toStringAsFixed(0)}',
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: tx.amount >= 0
                                      ? const Color(0xFF10B981)
                                      : cs.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final localDate = dt.toLocal();
    final diff = DateTime.now().difference(localDate);
    if (diff.isNegative) return 'Just now';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }

  Widget _buildStep(BuildContext context, String step, String text) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: tt.titleMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
