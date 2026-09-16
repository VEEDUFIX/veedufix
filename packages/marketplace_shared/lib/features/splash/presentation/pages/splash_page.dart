import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/app_mode.dart';
import '../../../../app/app_mode_routes.dart';
import '../../../../core/theme/abzio_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.mode = AppMode.customer,
  });

  final AppMode mode;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: widget.mode == AppMode.customer
                  ? SvgPicture.asset(
                      'assets/logo.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        AbzioTheme.accentColor,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(
                      splashIconForMode(widget.mode),
                      size: 46,
                      color: AbzioTheme.accentColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}