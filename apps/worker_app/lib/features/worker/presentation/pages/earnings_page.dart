import 'package:flutter/material.dart';

class EarningsPage extends StatelessWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PayoutCard(label: 'Today', amount: '₹2,450'),
          SizedBox(height: 12),
          _PayoutCard(label: 'This week', amount: '₹14,800'),
          SizedBox(height: 12),
          _PayoutCard(label: 'Withdrawn', amount: '₹42,000'),
        ],
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          amount,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
