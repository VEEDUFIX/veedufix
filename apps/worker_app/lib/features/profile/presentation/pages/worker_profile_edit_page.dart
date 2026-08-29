import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/worker_profile_providers.dart';

class WorkerProfileEditPage extends ConsumerStatefulWidget {
  const WorkerProfileEditPage({super.key});

  @override
  ConsumerState<WorkerProfileEditPage> createState() => _WorkerProfileEditPageState();
}

class _WorkerProfileEditPageState extends ConsumerState<WorkerProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _bioCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  bool _initialized = false;
  String? _avatarUrlOverride;

  @override
  void dispose() {
    _bioCtrl.dispose();
    _nameCtrl.dispose();
    _displayNameCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(Map<String, dynamic> profile) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _nameCtrl.text = profile['fullName'] as String? ?? '';
    _displayNameCtrl.text = profile['displayName'] as String? ?? '';
    _bioCtrl.text = profile['bio'] as String? ?? '';
    _expCtrl.text = (profile['experienceYears'] ?? 0).toString();
    _avatarUrlOverride = profile['avatarUrl'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final profileAsync = ref.watch(workerEditProfileProvider);
    final updateState = ref.watch(workerProfileUpdateProvider);

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
        title: Text('Edit Profile', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: updateState.isLoading ? null : _save,
              child: updateState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(child: Text('Unable to load profile.')),
        data: (profile) {
          _initFromProfile(profile);
          final workerId = profile['id'] as String? ?? '';
          final publicProfileAsync =
              workerId.isEmpty ? const AsyncValue<WorkerPublicProfile>.loading() : ref.watch(workerPublicProfileProvider(workerId));
          final categoriesAsync = ref.watch(workerSkillCategoriesProvider);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Center(
                  child: Stack(
                    children: [
                      MarketplaceNetworkAvatar(
                        imageUrl: _avatarUrlOverride ?? profile['avatarUrl'] as String?,
                        radius: 52,
                        backgroundColor: cs.primaryContainer,
                        fallback: Icon(Icons.person_rounded, size: 48, color: cs.onPrimaryContainer),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: TapScale(
                          onTap: _pickPhoto,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                            ),
                            child: Icon(Icons.camera_alt_rounded, size: 16, color: cs.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatPill(
                      icon: Icons.star_rounded,
                      label: ((profile['averageRating'] as num?) ?? 0).toStringAsFixed(1),
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 12),
                    _StatPill(
                      icon: Icons.check_circle_rounded,
                      label: '${profile['completedJobsCount'] ?? 0} jobs',
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _FieldLabel(label: 'Full Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDeco(context, hint: 'Your legal full name', icon: Icons.person_rounded),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const _FieldLabel(label: 'Display Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _displayNameCtrl,
                  decoration: _inputDeco(context, hint: 'Name shown to customers', icon: Icons.badge_rounded),
                ),
                const SizedBox(height: 16),
                const _FieldLabel(label: 'Bio'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioCtrl,
                  maxLines: 4,
                  decoration: _inputDeco(context, hint: 'Tell customers about your experience and skills...'),
                ),
                const SizedBox(height: 16),
                const _FieldLabel(label: 'Years of Experience'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _expCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco(context, hint: '0', icon: Icons.work_outline_rounded),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                      return 'Enter a whole number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Skills',
                  subtitle: 'Add the service categories you handle so customers can find you faster.',
                  trailing: TapScale(
                    onTap: categoriesAsync.hasValue && publicProfileAsync.hasValue
                        ? () => _openSkillPicker(
                              workerId,
                              context,
                              categoriesAsync.valueOrNull ?? const [],
                              publicProfileAsync.valueOrNull?.skills.map((skill) => skill.categorySlug).toSet() ?? <String>{},
                            )
                        : null,
                    child: Chip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add skill'),
                      backgroundColor: cs.primaryContainer.withValues(alpha: 0.7),
                      side: BorderSide.none,
                    ),
                  ),
                  child: publicProfileAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cs.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.badge_rounded, color: cs.error),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unable to load skills',
                                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Please try again. Your existing profile details can still be edited and saved.',
                                      style: tt.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    data: (publicProfile) {
                      final skills = publicProfile.skills;
                      if (skills.isEmpty) {
                        return Text(
                          'No skills added yet.',
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: skills
                            .map(
                              (skill) => Chip(
                                avatar: const Icon(Icons.handyman_rounded, size: 18),
                                label: Text(skill.categoryName),
                                backgroundColor: cs.surfaceContainerHighest,
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Portfolio',
                  subtitle: 'Show recent work so customers can trust your quality before they book.',
                  trailing: TapScale(
                    onTap: () => _pickPortfolioPhoto(workerId),
                    child: Chip(
                      avatar: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Add photo'),
                      backgroundColor: cs.primaryContainer.withValues(alpha: 0.7),
                      side: BorderSide.none,
                    ),
                  ),
                  child: publicProfileAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cs.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.photo_library_rounded, color: cs.error),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unable to load portfolio',
                                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your profile is safe. Try again when the connection is stable to view and manage portfolio photos.',
                                      style: tt.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    data: (publicProfile) {
                      if (publicProfile.portfolioPhotos.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No portfolio photos yet',
                                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add a few recent work shots to help customers trust your quality before they book.',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: publicProfile.portfolioPhotos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                        itemBuilder: (context, index) {
                          final photo = publicProfile.portfolioPhotos[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MarketplaceNetworkImage(
                                  imageUrl: photo.url,
                                  width: 320,
                                  height: 320,
                                  fit: BoxFit.cover,
                                ),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.7),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      photo.caption ?? 'Portfolio photo',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.labelMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (updateState.hasError) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Error: ${updateState.error}',
                      style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDeco(BuildContext context, {String? hint, IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null || !mounted) {
      return;
    }

    try {
      final repo = ref.read(workerProfileRepositoryProvider);
      final avatarUrl = await repo.uploadAvatar(image.path, image.name);
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        if (!mounted) {
          return;
        }
        setState(() => _avatarUrlOverride = avatarUrl);
        ref.invalidate(workerEditProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
        return;
      }

      throw Exception('Avatar upload did not return a URL.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo upload failed.')),
      );
    }
  }

  Future<void> _pickPortfolioPhoto(String workerId) async {
    if (workerId.isEmpty) {
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null || !mounted) {
      return;
    }

    try {
      final repo = ref.read(workerProfileRepositoryProvider);
      await repo.uploadPortfolioPhoto(image.path, image.name);

      ref.invalidate(workerEditProfileProvider);
      ref.invalidate(workerPublicProfileProvider(workerId));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portfolio photo added.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portfolio upload failed.')),
      );
    }
  }

  Future<void> _openSkillPicker(
    String workerId,
    BuildContext context,
    List<CatalogCategory> categories,
    Set<String> selectedSlugs,
  ) async {
    final filtered = categories.where((category) => !selectedSlugs.contains(category.slug)).toList(growable: false);
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All available skills are already added.')),
      );
      return;
    }

    final chosen = await showModalBottomSheet<CatalogCategory>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final visible = filtered.where((category) {
              if (query.trim().isEmpty) {
                return true;
              }
              final needle = query.toLowerCase().trim();
              return category.name.toLowerCase().contains(needle) || category.slug.toLowerCase().contains(needle);
            }).toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add a skill',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search categories',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: visible.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No matches found.')))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final category = visible[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: const Icon(Icons.handyman_rounded),
                                  ),
                                  title: Text(category.name),
                                  subtitle: Text(category.slug),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.of(sheetContext).pop(category),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chosen == null) {
      return;
    }

    try {
      final repo = ref.read(workerProfileRepositoryProvider);
      await repo.addSkill(chosen.id);
      
      ref.invalidate(workerEditProfileProvider);
      ref.invalidate(workerPublicProfileProvider(workerId));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${chosen.name} added to your skills.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to add skill.')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref.read(workerProfileUpdateProvider.notifier).update({
      'fullName': _nameCtrl.text.trim(),
      if (_displayNameCtrl.text.isNotEmpty) 'displayName': _displayNameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      if (_expCtrl.text.isNotEmpty) 'experienceYears': int.parse(_expCtrl.text),
    });
    if (!mounted) {
      return;
    }
    if (!ref.read(workerProfileUpdateProvider).hasError) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
