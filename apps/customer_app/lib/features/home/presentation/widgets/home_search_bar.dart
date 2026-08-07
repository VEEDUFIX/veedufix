import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.hint,
    required this.onVoiceTap,
  });

  final String hint;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TapScale(
        onTap: () => context.push('/search'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            boxShadow: AbzioTheme.eliteShadow,
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hint,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onVoiceTap,
                borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                    borderRadius:
                        BorderRadius.circular(AbzioTheme.buttonRadius),
                  ),
                  child:
                      Icon(Icons.mic_none_rounded, color: colorScheme.primary),
                ),
              ),
            ],
          ),
        ));
  }
}
