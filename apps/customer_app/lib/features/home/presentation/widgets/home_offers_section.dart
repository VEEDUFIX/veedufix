import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/metallic_card.dart';

class HomeOffersSection extends StatelessWidget {
  const HomeOffersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetallicCard(
          title: 'Festival offers',
          subtitle: 'Up to 25% off on essential home services this week.',
          icon: Icons.local_activity_rounded,
          baseColor: colorScheme.primary,
        ),
        const SizedBox(height: 12),
        MetallicCard(
          title: 'Referral rewards',
          subtitle: 'Invite friends and earn credits on your next booking.',
          icon: Icons.card_giftcard_rounded,
          baseColor: const Color(0xFF10B981),
          onTap: () => context.push('/referral'),
        ),
      ],
    );
  }
}
