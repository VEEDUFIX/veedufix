import 'package:flutter/material.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _BookingStatusCard(
            status: 'Worker assigned',
            booking: 'AC service for 2BHK flat',
            eta: 'Today, 3:30 PM',
          ),
          SizedBox(height: 12),
          _BookingStatusCard(
            status: 'Completed',
            booking: 'Kitchen plumbing fix',
            eta: '24 Jul 2026',
          ),
        ],
      ),
    );
  }
}

class _BookingStatusCard extends StatelessWidget {
  const _BookingStatusCard({
    required this.status,
    required this.booking,
    required this.eta,
  });

  final String status;
  final String booking;
  final String eta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(booking, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(eta),
          ],
        ),
      ),
    );
  }
}
