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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text('Wallet & Referrals', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(
          child: PremiumEmptyState(
            icon: Icons.wallet_rounded,
            title: 'Could not load wallet',
            subtitle: 'Pull down to refresh.',
          ),
        ),
        data: (wallet) => RefreshIndicator(
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
                  boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet Balance', style: tt.labelLarge?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 8),
                    Text(
                      '₹${wallet.balance.toStringAsFixed(2)}',
                      style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.people_rounded, color: Colors.white.withValues(alpha: 0.8), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${wallet.totalReferrals} referrals · ₹${wallet.referralEarnings.toStringAsFixed(0)} earned',
                          style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── Referral code card ─────────────────────────────────────
              PremiumCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Referral Code', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        'Share your code and both you and your friend earn ₹100 on their first booking!',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              wallet.referralCode,
                              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 2, color: cs.primary),
                            ),
                            TapScale(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: wallet.referralCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Referral code copied!')),
                                );
                              },
                              child: Icon(Icons.copy_rounded, color: cs.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Share.share(
                              '🏠 Try VeeduFix — Chennai\'s best home services app!\n\n'
                              'Use my referral code \'${wallet.referralCode}\' when you sign up '
                              'and we both get ₹100 wallet credits on your first booking.\n\n'
                              '🔗 Download: https://veedufix.app',
                            );
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share with Friends'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Transaction history ────────────────────────────────────
              Text('Transaction History', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (wallet.transactions.isEmpty)
                const PremiumEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No transactions yet',
                  subtitle: 'Your wallet activity will appear here.',
                )
              else
                ...wallet.transactions.map((tx) => Padding(
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
                              color: tx.type == 'CREDIT'
                                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                  : cs.errorContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              tx.type == 'CREDIT' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: tx.type == 'CREDIT' ? const Color(0xFF10B981) : cs.error,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.referenceType.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' '),
                                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  _formatDate(tx.createdAt),
                                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${tx.type == 'CREDIT' ? '+' : '-'}₹${tx.amount.toStringAsFixed(0)}',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: tx.type == 'CREDIT' ? const Color(0xFF10B981) : cs.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
