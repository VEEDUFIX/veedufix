import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';


class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({super.key, required this.professional});

  final HomeProfessional professional;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: PremiumCard(
        onTap: () => context.push(
          Uri(
            path: '/search',
            queryParameters: {'q': professional.name},
          ).toString(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      professional.accent.withValues(alpha: 0.22),
                      professional.accent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: professional.accent,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      professional.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (professional.verified)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.verified_rounded,
                          size: 18, color: Color(0xFF10B981)),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                professional.role,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              CompactMetric(
                  icon: Icons.workspace_premium_rounded,
                  label: professional.experience),
              const SizedBox(height: 8),
              CompactMetric(
                icon: Icons.star_rounded,
                label:
                    '${professional.rating.toStringAsFixed(1)} · ${professional.distance}',
              ),
              const SizedBox(height: 8),
              CompactMetric(
                icon: Icons.payments_rounded,
                label: professional.price,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopRatedCard extends StatelessWidget {
  const TopRatedCard({super.key, required this.professional});

  final HomeProfessional professional;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumCard(
      onTap: () => context.push(
        Uri(
          path: '/search',
          queryParameters: {'q': professional.name},
        ).toString(),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: professional.accent.withValues(alpha: 0.14),
          child: Text(
            professional.name.substring(0, 1),
            style: TextStyle(
              color: professional.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                professional.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (professional.verified)
              Icon(Icons.verified_rounded,
                  size: 18, color: colorScheme.secondary),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${professional.role} · ${professional.experience}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              professional.price,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  professional.rating.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CompactMetric extends StatelessWidget {
  const CompactMetric({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
