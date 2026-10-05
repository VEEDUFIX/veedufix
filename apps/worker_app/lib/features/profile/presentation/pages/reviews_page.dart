import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:intl/intl.dart';

class ReviewsPage extends ConsumerWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (session) {
        if (session == null) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Center(child: Text('Not authenticated')),
          );
        }

        final workerId = session.user.id;
        final profileAsync = ref.watch(workerProfileProvider(workerId));

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.surface,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: cs.onSurface),
              onPressed: () => context.pop(),
            ),
            title: Text('Reviews & Ratings',
                style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600, color: cs.onSurface)),
          ),
          body: profileAsync.when(
            data: (profile) {
              final reviews = profile.reviews.toList(growable: false)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(workerProfileProvider(workerId).future),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PremiumGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildOverallRating(cs, tt, profile),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Badges Earned',
                            style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                        const SizedBox(height: 16),
                        _buildBadgesScroll(cs, tt, profile, reviews),
                        const SizedBox(height: 24),
                        Text('Recent Reviews',
                            style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                        const SizedBox(height: 16),
                        if (reviews.isEmpty)
                          const PremiumEmptyState(
                            icon: Icons.star_border,
                            title: 'No reviews yet',
                            subtitle: 'Complete jobs to earn reviews',
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviews.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final review = reviews[index];
                              return _buildReviewItem(
                                cs: cs,
                                tt: tt,
                                review: review,
                                onRespond: () => _respondToReview(
                                  context,
                                  ref,
                                  workerId,
                                  review,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => PremiumRetryState(
              title: 'Could not load reviews',
              subtitle: 'Check your connection and try again.',
              icon: Icons.star_outline_rounded,
              onRetry: () => ref.invalidate(workerProfileProvider(workerId)),
              onRefresh: () async {
                await ref
                    .refresh(workerProfileProvider(workerId).future)
                    .then<void>((_) {});
              },
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Auth error'))),
    );
  }

  Future<void> _respondToReview(
    BuildContext context,
    WidgetRef ref,
    String workerId,
    WorkerPublicProfileReview review,
  ) async {
    final existingResponse = review.workerResponse?.trim();
    final hasResponse = existingResponse?.isNotEmpty == true;
    final controller = TextEditingController(text: existingResponse ?? '');
    try {
      final responseText = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(hasResponse ? 'Edit your reply' : 'Reply to review'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Thank the customer or address their feedback',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.length >= 3) Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Post reply'),
            ),
          ],
        ),
      );
      if (responseText == null || !context.mounted) return;

      await ref.read(apiClientProvider).patch(
        '/reviews/worker/${Uri.encodeComponent(review.id)}/response',
        data: {'response': responseText},
      );
      ref.invalidate(workerProfileProvider(workerId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your reply is now visible on your profile.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post your reply. Please try again.')),
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildOverallRating(
      ColorScheme cs, TextTheme tt, WorkerPublicProfile profile) {
    final reviews = profile.reviews;
    final total = reviews.length;

    int count5 = 0, count4 = 0, count3 = 0, count2 = 0, count1 = 0;
    for (var r in reviews) {
      if (r.rating >= 4.5) {
        count5++;
      } else if (r.rating >= 3.5) {
        count4++;
      } else if (r.rating >= 2.5) {
        count3++;
      } else if (r.rating >= 1.5) {
        count2++;
      } else {
        count1++;
      }
    }

    double pct(int count) => total == 0 ? 0 : count / total;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(profile.averageRating.toStringAsFixed(1),
                      style: tt.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(width: 4),
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFF59E0B), size: 32),
                ],
              ),
              const SizedBox(height: 4),
              Text('$total reviews',
                  style: tt.bodyMedium
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildRatingBar(5, pct(count5), cs, tt),
              const SizedBox(height: 4),
              _buildRatingBar(4, pct(count4), cs, tt),
              const SizedBox(height: 4),
              _buildRatingBar(3, pct(count3), cs, tt),
              const SizedBox(height: 4),
              _buildRatingBar(2, pct(count2), cs, tt),
              const SizedBox(height: 4),
              _buildRatingBar(1, pct(count1), cs, tt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingBar(
      int star, double percentage, ColorScheme cs, TextTheme tt) {
    return Row(
      children: [
        Text('$star',
            style: tt.bodySmall
                ?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
        Icon(Icons.star, size: 12, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: cs.onSurface.withValues(alpha: 0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
              minHeight: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesScroll(ColorScheme cs, TextTheme tt,
      WorkerPublicProfile profile, List<WorkerPublicProfileReview> reviews) {
    final List<Widget> badges = [];

    // Derive badges based on real data
    if (profile.averageRating >= 4.5) {
      badges.add(_buildBadgeItem(
          'Top Rated', Icons.emoji_events, const Color(0xFFB58B3A), cs, tt));
      badges.add(const SizedBox(width: 12));
    }

    // 5-star streak on the latest 3 reviews
    final latestReviews = reviews.take(3).toList(growable: false);
    if (latestReviews.length == 3 &&
        latestReviews.every((r) => r.rating == 5.0)) {
      badges.add(_buildBadgeItem(
          '5-Star Streak', Icons.star, const Color(0xFFF59E0B), cs, tt));
      badges.add(const SizedBox(width: 12));
    }

    if (profile.completedJobsCount >= 50) {
      badges.add(_buildBadgeItem(
          'Master', Icons.verified, const Color(0xFFB58B3A), cs, tt));
      badges.add(const SizedBox(width: 12));
    } else if (profile.completedJobsCount >= 10) {
      badges.add(_buildBadgeItem(
          'Experienced', Icons.work, const Color(0xFFB58B3A), cs, tt));
      badges.add(const SizedBox(width: 12));
    }

    if (badges.isEmpty) {
      badges.add(Text('No badges yet',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)));
    } else {
      badges.removeLast(); // remove trailing SizedBox
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: badges,
      ),
    );
  }

  Widget _buildBadgeItem(
      String title, IconData icon, Color color, ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: tt.labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required ColorScheme cs,
    required TextTheme tt,
    required WorkerPublicProfileReview review,
    required VoidCallback onRespond,
  }) {
    final hasWorkerResponse = review.workerResponse?.trim().isNotEmpty == true;
    final String initials = review.customerName.isNotEmpty
        ? review.customerName.substring(0, 1).toUpperCase()
        : '?';

    final dateStr = DateFormat.yMMMd().format(review.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MarketplaceNetworkAvatar(
                imageUrl: review.customerAvatarUrl,
                radius: 18,
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                fallback: Text(initials,
                    style: tt.titleMedium?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.customerName,
                        style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, color: cs.onSurface)),
                    Text(dateStr,
                        style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 4),
                    Text(review.rating.toStringAsFixed(1),
                        style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF59E0B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review.comment ?? '',
              style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
          const SizedBox(height: 10),
          if (hasWorkerResponse) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your reply', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(review.workerResponse!.trim(), style: tt.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRespond,
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: Text(hasWorkerResponse ? 'Edit reply' : 'Reply'),
            ),
          ),
        ],
      ),
    );
  }
}
