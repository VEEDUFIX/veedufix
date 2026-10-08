import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeOffersSection extends StatelessWidget {
  const HomeOffersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VeeduFixFeatureCard(
          title: 'Festival offers',
          subtitle: 'Up to 25% off on essential home services this week.',
          icon: Icons.local_activity_rounded,
        ),
        const SizedBox(height: 12),
        VeeduFixFeatureCard(
          title: 'Referral rewards',
          subtitle: 'Invite friends and earn credits on your next booking.',
          icon: Icons.card_giftcard_rounded,
          onTap: () => context.push('/referral'),
        ),
      ],
    );
  }
}
