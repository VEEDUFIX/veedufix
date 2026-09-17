import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeHeroBanner extends StatefulWidget {
  const HomeHeroBanner({
    super.key,
    required this.onTap,
    this.services = const [],
  });

  final VoidCallback onTap;
  final List<CatalogService> services;

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> {
  static const _slideDuration = Duration(seconds: 5);

  final _controller = PageController();
  Timer? _timer;
  int _activeIndex = 0;

  List<CatalogService> get _slides => widget.services.take(4).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _configureTimer();
  }

  @override
  void didUpdateWidget(covariant HomeHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services.length != widget.services.length) {
      _activeIndex = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
      _configureTimer();
    }
  }

  void _configureTimer() {
    _timer?.cancel();
    if (_slides.length < 2) {
      return;
    }
    _timer = Timer.periodic(_slideDuration, (_) {
      if (!mounted || !_controller.hasClients || _slides.length < 2) {
        return;
      }
      final nextIndex = (_activeIndex + 1) % _slides.length;
      _controller.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 420),
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
    final slides = _slides;
    final pageCount = slides.isEmpty ? 1 : slides.length;

    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: pageCount,
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemBuilder: (context, index) => _HeroSlide(
              service: slides.isEmpty ? null : slides[index],
              onTap: widget.onTap,
            ),
          ),
          if (pageCount > 1)
            Positioned(
              right: 18,
              top: 15,
              child: _PageDots(count: pageCount, activeIndex: _activeIndex),
            ),
        ],
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.service, required this.onTap});

  final CatalogService? service;
  final VoidCallback onTap;

  String? get _imageUrl {
    final images = service?.images ?? const <CatalogServiceImage>[];
    if (images.isNotEmpty) {
      return images.first.url;
    }
    final iconUrl = service?.iconUrl;
    return iconUrl?.isNotEmpty == true ? iconUrl : null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    final title = service?.name ?? 'Expert home services,\non demand.';
    final shortDescription = service?.shortDescription?.trim();
    final subtitle = shortDescription?.isNotEmpty == true
        ? shortDescription!
        : 'Verified professionals. Transparent pricing.';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF1A1208),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _FallbackBackground(),
              )
            else
              const _FallbackBackground(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xE8111111)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.12, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6A769),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FEATURED',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6A769),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Book now',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(left: 5),
          width: index == activeIndex ? 16 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: index == activeIndex ? 0.95 : 0.45),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _FallbackBackground extends StatelessWidget {
  const _FallbackBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1208), Color(0xFF3D2C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
