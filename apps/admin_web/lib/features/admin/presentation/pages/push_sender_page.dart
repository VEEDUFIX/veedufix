import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class PushSenderPage extends ConsumerStatefulWidget {
  const PushSenderPage({super.key});

  @override
  ConsumerState<PushSenderPage> createState() => _PushSenderPageState();
}

class _PushSenderPageState extends ConsumerState<PushSenderPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  String _targetRole = 'ALL';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/admin/notifications/broadcast', data: {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'targetRole': _targetRole,
        if (_routeCtrl.text.trim().isNotEmpty) 'route': _routeCtrl.text.trim(),
      });

      if (!mounted) return;

      final data = response;
      final successCount = data['successCount'] ?? 0;
      final failureCount = data['failureCount'] ?? 0;
      final total = data['totalCount'] ?? data['notificationCount'] ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Broadcast sent to $successCount/$total recipients ($failureCount failed).')),
      );

      _titleCtrl.clear();
      _bodyCtrl.clear();
      _routeCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send broadcast: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text('Broadcast Notification', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSectionHeader(title: 'Compose Message'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _targetRole,
                      decoration: InputDecoration(
                        labelText: 'Target Audience',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Users (Customers & Professionals)')),
                        DropdownMenuItem(value: 'CUSTOMER', child: Text('Customers Only')),
                        DropdownMenuItem(value: 'WORKER', child: Text('Professionals Only')),
                      ],
                      onChanged: (val) => setState(() => _targetRole = val ?? 'ALL'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Notification Title',
                        hintText: 'e.g. Flash Sale',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bodyCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Message Body',
                        hintText: 'e.g. Get 50% off all cleaning services this weekend.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Message is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _routeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Deep Link Route (Optional)',
                        hintText: 'e.g. /offers or /category/cleaning',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _sendBroadcast,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text(
                          'Send Broadcast',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
