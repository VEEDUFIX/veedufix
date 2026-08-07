import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MetallicCard extends StatefulWidget {
  const MetallicCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.baseColor = const Color(0xFF1E293B),
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color baseColor;
  final VoidCallback? onTap;

  @override
  State<MetallicCard> createState() => _MetallicCardState();
}

class _MetallicCardState extends State<MetallicCard> {
  double _tiltX = 0;
  double _tiltY = 0;
  StreamSubscription<AccelerometerEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        // Map accelerometer values to a subtle gradient shift (-1 to 1)
        _tiltX = (event.x / 9.8).clamp(-1.0, 1.0);
        _tiltY = (event.y / 9.8).clamp(-1.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic alignment based on device tilt
    final beginAlign = Alignment(-1.0 - _tiltX, -1.0 - _tiltY);
    final endAlign = Alignment(1.0 - _tiltX, 1.0 - _tiltY);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.baseColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          begin: beginAlign,
          end: endAlign,
          colors: [
            widget.baseColor,
            Color.lerp(widget.baseColor, Colors.white, 0.4)!,
            widget.baseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
