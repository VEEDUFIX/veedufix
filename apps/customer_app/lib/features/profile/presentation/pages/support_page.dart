import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final faqs = const [
      _Faq(
        q: 'How do I cancel a booking?',
        a: 'You can cancel a booking for free up to 2 hours before the scheduled time. '
            'Go to My Bookings, tap the booking, and select Cancel.',
      ),
      _Faq(
        q: 'What if the professional does not arrive?',
        a: 'If the professional is more than 30 minutes late without notice, you can '
            'contact our 24/7 support or cancel for a full refund.',
      ),
      _Faq(
        q: 'Is there a warranty on the work done?',
        a: 'Yes. All services carry a 30-day workmanship warranty. If you face any '
            'issues with the completed job, raise a request and we will resolve it at no charge.',
      ),
      _Faq(
        q: 'How do referral rewards work?',
        a: 'Share your unique referral code. When a friend makes their first booking '
            'using your code, you both receive ₹100 in wallet credits.',
      ),
      _Faq(
        q: 'What payment methods are accepted?',
        a: 'We accept UPI, debit/credit cards, net banking, and wallet balance.',
      ),
    ];

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
        title: Text('Help & Support',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ─── Contact card ───────────────────────────────────────────────
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child:
                            Icon(Icons.headset_mic_rounded, color: cs.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('24/7 Customer Care',
                                style: tt.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text('We typically reply within 5 minutes.',
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TapScale(
                          onTap: () {},
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.primary),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.call_rounded,
                                    color: cs.primary, size: 18),
                                const SizedBox(width: 8),
                                Text('Call Us',
                                    style: tt.labelLarge?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TapScale(
                          onTap: () {},
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_rounded,
                                    color: cs.onPrimary, size: 18),
                                const SizedBox(width: 8),
                                Text('Live Chat',
                                    style: tt.labelLarge?.copyWith(
                                        color: cs.onPrimary,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ─── Report issue ─────────────────────────────────────────────
          Text('Report an Issue',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          const _SupportOption(
            icon: Icons.receipt_long_rounded,
            label: 'Issue with a booking',
            accent: Color(0xFFF59E0B),
          ),
          const _SupportOption(
            icon: Icons.payment_rounded,
            label: 'Payment or refund issue',
            accent: Color(0xFF10B981),
          ),
          const _SupportOption(
            icon: Icons.person_rounded,
            label: 'Report a professional',
            accent: Color(0xFFEF4444),
          ),
          const SizedBox(height: 32),

          // ─── FAQ ──────────────────────────────────────────────────────
          Text('Frequently Asked Questions',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ...faqs.map((f) => _FaqTile(faq: f)),
        ],
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({required this.icon, required this.label, required this.accent});
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TapScale(
        onTap: () {},
        child: PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: tt.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Faq {
  const _Faq({required this.q, required this.a});
  final String q;
  final String a;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});
  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: PremiumCard(
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Text(
              faq.q,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            children: [
              Text(
                faq.a,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
