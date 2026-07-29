import 'package:flutter/material.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

class LiquidRefresh extends StatelessWidget {
  const LiquidRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      builder: (
        BuildContext context,
        Widget child,
        IndicatorController controller,
      ) {
        return AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, _) {
            final double value = controller.value.clamp(0.0, 1.0);
            
            return Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                if (!controller.isIdle)
                  Positioned(
                    top: 25.0 + (10.0 * value),
                    child: Container(
                      width: 40 * value,
                      height: 40 * value,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: controller.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(10.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.arrow_downward_rounded,
                              color: Colors.white,
                              size: 20 * value,
                            ),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(0, 65.0 * value),
                  child: child,
                ),
              ],
            );
          },
        );
      },
      child: child,
    );
  }
}
