import 'package:flutter/material.dart';

import '../widgets/admin_surface.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Analytics',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: const [
          AdminSurfacePanel(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'City growth overview',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: kAdminInk,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Track bookings, worker supply, revenue, and support trends as the city expands.',
                    style: TextStyle(
                      color: kAdminMuted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
