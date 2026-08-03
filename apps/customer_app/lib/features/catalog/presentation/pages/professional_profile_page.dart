import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class ProfessionalProfilePage extends ConsumerWidget {
  const ProfessionalProfilePage({super.key, required this.professionalId});

  final String professionalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final profileAsync = ref.watch(workerProfileProvider(professionalId));

    return Scaffold(
      backgroundColor: cs.surface,
      body: profileAsync.when(
        loading: () => _LoadingScaffold(cs: cs),
        error: (err, _) => Scaffold(
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
          ),
          body: const Center(
            child: PremiumEmptyState(
              icon: Icons.person_off_rounded,
              title: 'Profile not found',
              subtitle: 'We could not load this professional\'s profile.',
            ),
          ),
        ),
        data: (profile) => _ProfileBody(profile: profile, professionalId: professionalId),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cs.surface,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.professionalId});
  final WorkerPublicProfile profile;
  final String professionalId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    const accent = Color(0xFFC2A15E);

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
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
            title: Text('Professional', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Profile header ───────────────────────────────────────
                  Row(
                    children: [
                      Hero(
                        tag: 'pro-$professionalId',
                        child: MarketplaceNetworkAvatar(
                          imageUrl: profile.avatarUrl,
                          radius: 42,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          fallback: Text(
                            profile.displayName.substring(0, 1).toUpperCase(),
                            style: tt.displaySmall?.copyWith(color: accent, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    profile.displayName,
                                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (profile.verificationStatus == 'APPROVED')
                                  Icon(Icons.verified_rounded, size: 18, color: cs.secondary),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (profile.bio != null)
                              Text(
                                profile.bio!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── Stats row ─────────────────────────────────────────────
                  Row(
                    children: [
                      _StatBadge(
                        icon: Icons.star_rounded,
                        value: profile.averageRating.toStringAsFixed(1),
                        label: 'Rating',
                        accent: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 12),
                      _StatBadge(
                        icon: Icons.work_rounded,
                        value: profile.completedJobsCount.toString(),
                        label: 'Jobs done',
                        accent: cs.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatBadge(
                        icon: Icons.history_edu_rounded,
                        value: '${profile.experienceYears} yrs',
                        label: 'Experience',
                        accent: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ─── Skills ────────────────────────────────────────────────
                  if (profile.skills.isNotEmpty) ...[
                    Text('Skills & Expertise', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.skills.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                        ),
                        child: Text(
                          s.categoryName,
                          style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ─── Portfolio photos ──────────────────────────────────────
                  if (profile.portfolioPhotos.isNotEmpty) ...[
                    Text('Portfolio', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: profile.portfolioPhotos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final photo = profile.portfolioPhotos[i];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                            child: MarketplaceNetworkImage(
                              imageUrl: photo.url,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                              borderRadius: AbzioTheme.buttonRadius,
                              cloudinaryWidth: 220,
                              cloudinaryHeight: 220,
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ─── Reviews ──────────────────────────────────────────────
                  if (profile.reviews.isNotEmpty) ...[
                    Text('Customer Reviews', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: profile.reviews.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _ReviewCard(review: profile.reviews[index]);
                      },
                    ),
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, -10))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TapScale(
                  onTap: () => _openMessageOptions(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.primary),
                      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Message', style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TapScale(
                  onTap: () => context.push('/checkout'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                      boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Text(
                      'Book This Pro',
                      textAlign: TextAlign.center,
                      style: tt.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMessageOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Message this professional',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Messaging starts after you book this professional, so the fastest next step is to open checkout.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/checkout');
                  },
                  child: const Text('Book now'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/search');
                  },
                  child: const Text('Browse similar services'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.icon, required this.value, required this.label, required this.accent});
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(height: 6),
            Text(value, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final WorkerPublicProfileReview review;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PremiumCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                  MarketplaceNetworkAvatar(
                    imageUrl: review.customerAvatarUrl,
                    radius: 18,
                    backgroundColor: cs.primaryContainer,
                    fallback: Text(
                      review.customerName.substring(0, 1).toUpperCase(),
                      style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.customerName, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          _timeAgo(review.createdAt),
                          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14,
                      color: const Color(0xFFF59E0B),
                    )),
                  ),
                ],
              ),
              if (review.comment != null) ...[
                const SizedBox(height: 10),
                Text(
                  review.comment!,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    return 'Just now';
  }
}
