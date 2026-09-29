import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/worker_profile_providers.dart';

class DocumentUploadPage extends ConsumerStatefulWidget {
  const DocumentUploadPage({super.key});

  @override
  ConsumerState<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends ConsumerState<DocumentUploadPage> {
  final _picker = ImagePicker();
  bool _isUploading = false;
  String _docType = 'aadhaar';
  XFile? _pickedFile;
  String? _lastError;

  Future<void> _pickDocument() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file != null && mounted) {
      setState(() {
        _pickedFile = file;
        _lastError = null;
      });
    }
  }

  Future<void> _uploadDocument() async {
    final file = _pickedFile;
    if (file == null || _isUploading) return;
    setState(() {
      _isUploading = true;
      _lastError = null;
    });
    try {
      await ref.read(workerProfileRepositoryProvider).uploadWorkerDocumentFile(
            type: _docType,
            imagePath: file.path,
            filename: file.name,
          );
      if (!mounted) return;
      ref.invalidate(workerDocumentsProvider);
      setState(() => _pickedFile = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded for review.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _lastError = error.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text('My Documents', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PremiumSectionHeader(title: 'Upload a document'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _docType,
                        decoration: InputDecoration(
                          labelText: 'Document type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'aadhaar', child: Text('Aadhaar')),
                          DropdownMenuItem(value: 'pan', child: Text('PAN')),
                          DropdownMenuItem(value: 'driving_license', child: Text('Driving licence')),
                          DropdownMenuItem(value: 'passport', child: Text('Passport')),
                          DropdownMenuItem(value: 'voter_id', child: Text('Voter ID')),
                          DropdownMenuItem(value: 'other', child: Text('Other identity document')),
                        ],
                        onChanged: _isUploading ? null : (value) {
                          if (value != null) setState(() => _docType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isUploading ? null : _pickDocument,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(_pickedFile?.name ?? 'Choose document photo'),
                      ),
                      const SizedBox(height: 8),
                      Text('Choose a clear photo of the document. Your current verified documents are not changed until this upload is reviewed.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      if (_lastError != null) ...[
                        const SizedBox(height: 12),
                        Text(_lastError!, style: TextStyle(color: cs.error)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _isUploading || _pickedFile == null ? null : _uploadDocument,
                          child: _isUploading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Upload for verification'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: PremiumSectionHeader(title: 'Uploaded documents'),
            ),
          ),
          asyncDocs.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (error, _) => SliverFillRemaining(child: Center(child: Text('Could not load documents: $error'))),
            data: (docs) {
              if (docs.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text('No documents uploaded yet.')));
              }
              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = docs[index];
                      final status = (doc['status'] ?? (doc['verifiedAt'] != null ? 'VERIFIED' : 'PENDING')).toString();
                      final verified = status.toUpperCase() == 'VERIFIED';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PremiumGlassCard(
                          child: ListTile(
                            leading: Icon(Icons.description_rounded, color: verified ? Colors.green : cs.primary),
                            title: Text((doc['type'] ?? 'Document').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(verified ? 'Verified' : status == 'REJECTED' ? 'Action required' : 'Under review', style: TextStyle(color: verified ? Colors.green : cs.onSurfaceVariant)),
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
