import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/shimmer_placeholder.dart';
import '../../domain/entities/home_banner.dart';

class HomeHeroBanner extends StatefulWidget {
  const HomeHeroBanner({super.key, required this.banners, required this.onTap});

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onTap;

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _configureTimer();
  }

  @override
  void didUpdateWidget(covariant HomeHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.banners.map((banner) => banner.id).join('|');
    final newIds = widget.banners.map((banner) => banner.id).join('|');
    if (oldIds != newIds) {
      _activeIndex = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _configureTimer();
    }
  }

  void _configureTimer() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients || widget.banners.length < 2) {
        return;
      }
      final next = (_activeIndex + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width - 32;
    final height = width < 308
        ? 160.0
        : width >= 360
        ? 176.0
        : 172.0;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.banners.length,
          onPageChanged: (index) => setState(() => _activeIndex = index),
          itemBuilder: (context, index) {
            final banner = widget.banners[index];
            return Semantics(
              button: true,
              label:
                  'Home promotion ${index + 1} of ${widget.banners.length}. Tap to open.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onTap(banner),
                child: Image.network(
                  banner.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: height,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : ShimmerPlaceholder(
                          width: double.infinity,
                          height: height,
                          borderRadius: 0,
                        ),
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFFECE6DB)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
