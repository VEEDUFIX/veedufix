import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmergencyContactCard(context),
            const SizedBox(height: 24),
            Text('Frequently Asked Questions', style: tt.titleLarge),
            const SizedBox(height: 16),
            _buildFaqList(),
            const SizedBox(height: 32),
            Text('Raise a Ticket', style: tt.titleLarge),
            const SizedBox(height: 16),
            _buildTicketForm(context),
            const SizedBox(height: 32),
            Text('Other ways to contact us', style: tt.titleMedium),
            const SizedBox(height: 16),
            _buildContactOptions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactCard(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade400,
            Colors.red.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Contact',
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap here to call support instantly for active job emergencies.',
                  style: tt.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqList() {
    final faqs = [
      {
        'q': 'How do I get paid?',
        'a': 'Payments are settled directly to your registered bank account within 24 hours of job completion.'
      },
      {
        'q': 'What if the customer cancels the job?',
        'a': 'If the customer cancels within 2 hours of the scheduled time, you will receive a cancellation fee.'
      },
      {
        'q': 'How can I update my service areas?',
        'a': 'Go to Profile > Settings > Service Areas to update the regions you want to receive job requests from.'
      },
      {
        'q': 'Can I decline a job request?',
        'a': 'Yes, you can decline job requests, but maintaining a high acceptance rate is recommended for better visibility.'
      },
      {
        'q': 'What should I do if I\'m running late?',
        'a': 'Please use the in-app chat to inform the customer as soon as possible, or contact support if the delay is significant.'
      },
    ];

    return Column(
      children: faqs
          .map((faq) => ExpansionTile(
                title: Text(faq['q']!),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(faq['a']!),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildTicketForm(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          initialValue: _selectedCategory,
          items: const [
            DropdownMenuItem(value: 'payment', child: Text('Payment Issue')),
            DropdownMenuItem(value: 'app', child: Text('App Issue')),
            DropdownMenuItem(value: 'customer', child: Text('Customer Issue')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (val) {
            setState(() {
              _selectedCategory = val;
            });
          },
        ),
        const SizedBox(height: 16),
        const TextField(
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Describe your issue in detail...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: PrimaryActionButton(
            onPressed: () {},
            label: 'Submit Ticket', // Assumed parameter from marketplace_shared
          ),
        ),
      ],
    );
  }

  Widget _buildContactOptions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ContactOption(
          icon: Icons.email,
          label: 'Email',
          color: cs.primary,
        ),
        const _ContactOption(
          icon: Icons.phone,
          label: 'Phone',
          color: Colors.green,
        ),
        const _ContactOption(
          icon: Icons.chat,
          label: 'WhatsApp',
          color: Color(0xFF25D366),
        ),
      ],
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ContactOption({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(label, style: tt.bodySmall),
      ],
    );
  }
}
