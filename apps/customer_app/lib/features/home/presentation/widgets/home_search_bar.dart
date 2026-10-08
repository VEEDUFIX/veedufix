import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key, required this.onVoiceTap});

  final VoidCallback onVoiceTap;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  static const _examples = [
    'AC service',
    'Plumbing',
    'Deep cleaning',
    'Electrician',
    'Home cleaning',
    'Carpenter',
  ];

  Timer? _placeholderTimer;
  int _exampleIndex = 0;
  bool _searchTapped = false;

  @override
  void initState() {
    super.initState();
    _startPlaceholderTimer();
  }

  void _startPlaceholderTimer() {
    _placeholderTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted || _searchTapped) return;
      setState(() => _exampleIndex = (_exampleIndex + 1) % _examples.length);
    });
  }

  Future<void> _openSearch() async {
    _placeholderTimer?.cancel();
    setState(() => _searchTapped = true);
    await context.push('/search');
    if (!mounted) return;
    setState(() => _searchTapped = false);
    _startPlaceholderTimer();
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholderStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AbzioTheme.lightTextSecondary,
    );

    return TapScale(
      onTap: _openSearch,
      child: Semantics(
        button: true,
        label: 'Search services',
        explicitChildNodes: true,
        child: Container(
          height: VeeduFixDesignSystem.inputHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AbzioTheme.lightBorder, width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AbzioTheme.lightTextSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.12),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: _searchTapped
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : RichText(
                          key: ValueKey(_examples[_exampleIndex]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style:
                                placeholderStyle ??
                                const TextStyle(fontSize: 15),
                            children: [
                              const TextSpan(text: 'Search for '),
                              TextSpan(text: '“${_examples[_exampleIndex]}”'),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: AbzioTheme.lightBorder),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Search by voice',
                child: GestureDetector(
                  onTap: widget.onVoiceTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AbzioTheme.accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.mic_none_rounded,
                      size: 18,
                      color: AbzioTheme.accentColor,
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
}
