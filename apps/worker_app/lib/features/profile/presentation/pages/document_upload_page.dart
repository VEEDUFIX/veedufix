import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/worker_profile_providers.dart';

class DocumentUploadPage extends ConsumerStatefulWidget {
  const DocumentUploadPage({super.key});

  @override
  ConsumerState<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends ConsumerState<DocumentUploadPage> {
  bool _isUploading = false;
  String _docType = 'AADHAAR';
  final _urlCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _lastError;
  String? _lastUrl;
  String? _lastType;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadDocument() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);
    final url = _urlCtrl.text.trim();

    try {
      final repo = ref.read(workerProfileRepositoryProvider);
      await repo.uploadDocument(_docType, url);
      
      if (!mounted) return;
      ref.invalidate(workerDocumentsProvider);
      setState(() {
        _lastError = null;
        _lastUrl = null;
        _lastType = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully')),
      );
      _urlCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e.toString();
        _lastUrl = url;
        _lastType = _docType;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload document: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _retryLastUpload() async {
    if (_lastUrl == null || _lastType == null) {
      return;
    }
    _urlCtrl.text = _lastUrl!;
    setState(() => _docType = _lastType!);
    await _uploadDocument();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final asyncDocs = ref.watch(workerDocumentsProvider);

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
        title: Text('My Documents', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_lastError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Upload failed',
                                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.red),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _lastError!,
                                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  onPressed: _isUploading ? null : _retryLastUpload,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry upload'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const PremiumSectionHeader(title: 'Upload New Document'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _docType,
                          decoration: InputDecoration(
                            labelText: 'Document Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'AADHAAR', child: Text('Aadhaar Card')),
                            DropdownMenuItem(value: 'PAN', child: Text('PAN Card')),
                            DropdownMenuItem(value: 'CERTIFICATE', child: Text('Professional Certificate')),
                          ],
                          onChanged: (val) => setState(() => _docType = val!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _urlCtrl,
                          decoration: InputDecoration(
                            labelText: 'Document File URL',
                            hintText: 'https://...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'URL is required' : null,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Paste a public or pre-signed document URL. If the network fails, you can retry without redoing the form.',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _isUploading ? null : _uploadDocument,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isUploading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Upload', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: PremiumSectionHeader(title: 'Uploaded Documents'),
            ),
          ),

          asyncDocs.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, st) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            data: (docs) {
              if (docs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No documents uploaded yet.')),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = docs[index];
                      final verifiedAt = doc['verifiedAt'];
                      final isVerified = verifiedAt != null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PremiumGlassCard(
                          child: ListTile(
                            leading: Icon(
                              Icons.description_rounded,
                              color: isVerified ? Colors.green : cs.primary,
                            ),
                            title: Text(doc['type'] ?? 'Document', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              isVerified ? 'Verified on $verifiedAt' : 'Pending Verification',
                              style: TextStyle(color: isVerified ? Colors.green : Colors.orange),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
