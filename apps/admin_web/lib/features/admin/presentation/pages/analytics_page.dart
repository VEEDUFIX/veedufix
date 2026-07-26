import 'package:flutter/material.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'City growth overview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 12),
                Text(
                  'Track bookings, worker supply, revenue, and support trends as the city expands.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
