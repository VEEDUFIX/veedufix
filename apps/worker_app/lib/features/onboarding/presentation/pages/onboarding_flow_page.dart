import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/onboarding_provider.dart';

class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  final _formKeys = List<GlobalKey<FormState>>.generate(4, (_) => GlobalKey<FormState>());
  final _fullNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _upiController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  late PageController _pageController;

  DateTime? _selectedDateOfBirth;
  bool _initialized = false;
  bool _seededFromProfile = false;
  int _initialStep = 0;
  bool _editMode = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _aadhaarController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final routerState = GoRouterState.of(context);
    final query = routerState.uri.queryParameters;
    _editMode = query['mode'] == 'edit';
    _initialStep = int.tryParse(query['step'] ?? '')?.clamp(0, 4) ?? 0;
    _pageController = PageController(initialPage: _initialStep);

    unawaited(
      ref.read(onboardingControllerProvider.notifier).bootstrap(
            editMode: _editMode,
            step: _initialStep,
          ),
    );

    _initialized = true;
  }

  void _seedControllers(WorkerOnboardingProfile profile) {
    _fullNameController.text = profile.fullName ?? '';
    _dateOfBirthController.text = profile.dateOfBirth == null
        ? ''
        : DateFormat.yMMMMd().format(profile.dateOfBirth!);
    _addressController.text = profile.addressLine1 ?? '';
    _cityController.text = profile.city ?? '';
    _pincodeController.text = profile.pincode ?? '';
    _aadhaarController.text = '';
    _upiController.text = profile.upiId ?? '';
    _bankAccountController.text = profile.bankAccountNumber ?? '';
    _bankIfscController.text = profile.bankIfsc ?? '';
    _selectedDateOfBirth = profile.dateOfBirth;
    _seededFromProfile = true;
  }

  Future<void> _pickDateOfBirth(WorkerOnboardingController controller) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 15),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedDateOfBirth = selected;
      _dateOfBirthController.text = DateFormat.yMMMMd().format(selected);
    });

    controller.updatePersonalDetails(dateOfBirth: selected);
  }

  Future<void> _pickDocumentSource(void Function(XFile file) onPicked) async {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (picked == null) {
      return;
    }

    final file = await ImagePicker().pickImage(
      source: picked,
      imageQuality: 88,
    );
    if (file != null) {
      onPicked(file);
    }
  }

  Future<void> _saveStep1(WorkerOnboardingController controller) async {
    if (!_formKeys[0].currentState!.validate()) {
      return;
    }

    controller.updatePersonalDetails(
      fullName: _fullNameController.text.trim(),
      dateOfBirth: _selectedDateOfBirth,
      addressLine1: _addressController.text.trim(),
      city: _cityController.text.trim(),
      pincode: _pincodeController.text.trim(),
    );

    await controller.savePersonalDetails();
    controller.nextStep();
  }

  Future<void> _saveStep2(WorkerOnboardingController controller) async {
    if (!_formKeys[1].currentState!.validate()) {
      return;
    }

    final state = ref.read(onboardingControllerProvider);
    final documentFile = state.draft.aadhaarDocumentFile;
    final hasSavedDocument = state.profile?.hasAadhaarDoc ?? false;

    if (documentFile == null && !hasSavedDocument) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload your Aadhaar document before continuing.')),
      );
      return;
    }

    controller.updateIdentityDetails(
      aadhaarNumber: _aadhaarController.text.trim(),
    );

    await controller.savePersonalDetails();
    if (documentFile != null) {
      await controller.saveIdentityDocument(documentFile);
    }
    controller.nextStep();
  }

  Future<void> _saveStep3(WorkerOnboardingController controller) async {
    if (ref.read(onboardingControllerProvider).draft.selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one service category.')),
      );
      return;
    }

    await controller.saveSkills();
    controller.nextStep();
  }

  Future<void> _saveStep4(WorkerOnboardingController controller) async {
    if (!_formKeys[3].currentState!.validate()) {
      return;
    }

    controller.updateBankDetails(
      upiId: _upiController.text.trim(),
      bankAccountNumber: _bankAccountController.text.trim(),
      bankIfsc: _bankIfscController.text.trim(),
    );

    await controller.saveBankDetails();
    controller.nextStep();
  }

  Future<void> _submit(WorkerOnboardingController controller) async {
    try {
      await controller.submitForReview();
      if (!mounted) {
        return;
      }
      context.go('/onboarding/status');
    } catch (_) {
      if (!mounted) {
        return;
      }
      final state = ref.read(onboardingControllerProvider);
      final step = state.currentStep;
      if (state.missingFields.isNotEmpty) {
        final nextStep = _stepForField(state.missingFields.first);
        controller.setStep(nextStep);
      } else {
        controller.setStep(step);
      }
    }
  }

  int _stepForField(String field) {
    switch (field) {
      case 'fullName':
      case 'dateOfBirth':
      case 'addressLine1':
      case 'city':
      case 'pincode':
        return 0;
      case 'aadhaarNumber':
      case 'aadhaarDocUrl':
        return 1;
      case 'skills':
        return 2;
      case 'upiId':
      case 'bankAccountNumber':
      case 'bankIfsc':
        return 3;
      default:
        return 0;
    }
  }

  IconData _iconForCategory(CatalogCategory category) {
    switch (category.slug.toLowerCase()) {
      case 'electrician':
        return Icons.electrical_services_rounded;
      case 'plumber':
        return Icons.plumbing_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'carpenter':
        return Icons.handyman_rounded;
      case 'ac-repair':
      case 'ac service':
        return Icons.ac_unit_rounded;
      case 'painter':
        return Icons.format_paint_rounded;
      case 'laptop-repair':
        return Icons.computer_rounded;
      case 'mobile-repair':
        return Icons.phone_android_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

    ref.listen<WorkerOnboardingState>(onboardingControllerProvider, (previous, next) {
      if (!_seededFromProfile && next.profile != null) {
        _seedControllers(next.profile!);
      }

      if (previous?.currentStep != next.currentStep && _pageController.hasClients) {
        _pageController.animateToPage(
          next.currentStep,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });

    if (state.isLoadingProfile && state.profile == null) {
      return _buildLoadingScaffold(context);
    }

    final totalSteps = 5;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFBF5),
              Color(0xFFF6F1E8),
              Color(0xFFFBFAF7),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -48,
              right: -38,
              child: _DecorativeGlow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: 120,
              left: -56,
              child: _DecorativeGlow(color: const Color(0xFFF59E0B).withValues(alpha: 0.13), size: 150),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: PremiumGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 56,
                                  width: 56,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                                  ),
                                  child: Icon(
                                    Icons.badge_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Worker onboarding',
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.4,
                                                  ),
                                            ),
                                          ),
                                          if (state.currentStep > 0)
                                            IconButton(
                                              onPressed: state.currentStep == 0
                                                  ? null
                                                  : () => ref.read(onboardingControllerProvider.notifier).previousStep(),
                                              icon: const Icon(Icons.arrow_back_rounded),
                                              tooltip: 'Back',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Complete your profile once and we will handle the rest. Approved workers can start getting jobs quickly.',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              height: 1.45,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _HeaderBadge(
                                  icon: Icons.save_outlined,
                                  label: 'Auto-saved draft',
                                  accent: Theme.of(context).colorScheme.primary,
                                ),
                                const _HeaderBadge(
                                  icon: Icons.verified_user_outlined,
                                  label: 'Secure verification',
                                  accent: Color(0xFF0F766E),
                                ),
                                const _HeaderBadge(
                                  icon: Icons.timer_outlined,
                                  label: '5-7 minute flow',
                                  accent: Color(0xFFF59E0B),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: (state.currentStep + 1) / totalSteps,
                                minHeight: 10,
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Step ${state.currentStep + 1} of $totalSteps',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                  ),
                                ),
                                Text(
                                  _labelForStep(state.currentStep),
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (var index = 0; index < totalSteps; index++)
                                  _StepPill(
                                    index: index + 1,
                                    label: _labelForStep(index),
                                    active: index == state.currentStep,
                                    complete: index < state.currentStep,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                              const SizedBox(width: 12),
                              Expanded(child: Text(state.errorMessage!)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildPersonalDetailsStep(state),
                        _buildIdentityStep(state),
                        _buildSkillsStep(state),
                        _buildBankStep(state),
                        _buildReviewStep(state),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFBF5), Color(0xFFF7F1E7), Color(0xFFFAF9F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: PremiumGlassCard(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text(
                    'Loading your onboarding flow...',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _labelForStep(int index) {
    switch (index) {
      case 0:
        return 'Personal';
      case 1:
        return 'Identity';
      case 2:
        return 'Skills';
      case 3:
        return 'Bank';
      default:
        return 'Review';
    }
  }

  Widget _buildPersonalDetailsStep(WorkerOnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const PremiumSectionHeader(
          title: 'Personal details',
          subtitle: 'Tell us who you are and where you work from.',
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKeys[0],
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    onChanged: (value) => controller.updatePersonalDetails(fullName: value),
                    validator: (value) {
                      if ((value ?? '').trim().length < 2) {
                        return 'Enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _dateOfBirthController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: Icon(Icons.cake_rounded),
                    ),
                    onTap: () => _pickDateOfBirth(controller),
                    validator: (_) {
                      if (_selectedDateOfBirth == null) {
                        return 'Select your date of birth';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address line 1',
                      prefixIcon: Icon(Icons.home_rounded),
                    ),
                    onChanged: (value) => controller.updatePersonalDetails(addressLine1: value),
                    validator: (value) {
                      if ((value ?? '').trim().length < 5) {
                        return 'Enter your address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            prefixIcon: Icon(Icons.location_city_rounded),
                          ),
                          onChanged: (value) => controller.updatePersonalDetails(city: value),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter your city';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Pincode',
                            prefixIcon: Icon(Icons.local_post_office_rounded),
                          ),
                          onChanged: (value) => controller.updatePersonalDetails(pincode: value),
                          validator: (value) {
                            if ((value ?? '').trim().length < 5) {
                              return 'Enter a valid pincode';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PrimaryActionButton(
                    label: state.isSavingProfile ? 'Saving...' : 'Next',
                    onPressed: state.isSavingProfile ? null : () => unawaited(_saveStep1(controller)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityStep(WorkerOnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final savedMask = state.draft.savedAadhaarMask ?? state.profile?.maskedAadhaar();
    final selectedDocumentName = state.draft.aadhaarDocumentFile?.name;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const PremiumSectionHeader(
          title: 'Identity document',
          subtitle: 'Verify your Aadhaar number and upload the document image.',
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKeys[1],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _aadhaarController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Aadhaar number',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      helperText: savedMask == null ? 'We will only show the last 4 digits after saving.' : 'Saved as $savedMask',
                    ),
                    onChanged: (value) => controller.updateIdentityDetails(aadhaarNumber: value),
                    validator: (value) {
                      if ((value ?? '').trim().length < 12) {
                        return 'Enter a valid Aadhaar number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isUploadingDocument
                              ? null
                              : () => _pickDocumentSource((file) {
                                    controller.setAadhaarDocumentFile(file);
                                  }),
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload document'),
                        ),
                      ),
                    ],
                  ),
                  if (selectedDocumentName != null) ...[
                    const SizedBox(height: 10),
                    _FileTag(label: selectedDocumentName),
                  ],
                  const SizedBox(height: 18),
                  PrimaryActionButton(
                    label: state.isSavingProfile || state.isUploadingDocument ? 'Saving...' : 'Next',
                    onPressed: (state.isSavingProfile || state.isUploadingDocument)
                        ? null
                        : () => unawaited(_saveStep2(controller)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsStep(WorkerOnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);

    if (state.isLoadingCategories && state.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const PremiumSectionHeader(
          title: 'Skills selection',
          subtitle: 'Choose the services you want to work in and upload certificates if available.',
        ),
        const SizedBox(height: 12),
        ...state.categories.map(
          (category) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                          ),
                          child: Icon(_iconForCategory(category), color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (category.description != null && category.description!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    category.description!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: state.draft.selectedCategoryIds.contains(category.id),
                          onChanged: (value) {
                            controller.toggleCategory(category.id, value ?? false);
                          },
                        ),
                      ],
                    ),
                    if (state.draft.selectedCategoryIds.contains(category.id)) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDocumentSource((file) {
                                controller.setCertificationFile(category.id, file);
                              }),
                              icon: const Icon(Icons.badge_rounded),
                              label: Text(
                                state.draft.certificationFiles[category.id]?.name ?? 'Add certificate (optional)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        PrimaryActionButton(
          label: state.isSavingSkills ? 'Saving...' : 'Next',
          onPressed: state.isSavingSkills ? null : () => unawaited(_saveStep3(controller)),
        ),
      ],
    );
  }

  Widget _buildBankStep(WorkerOnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const PremiumSectionHeader(
          title: 'Bank and UPI',
          subtitle: 'UPI is the primary payout method. Bank details are optional fallback.',
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKeys[3],
              child: Column(
                children: [
                  TextFormField(
                    controller: _upiController,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    onChanged: (value) => controller.updateBankDetails(upiId: value),
                    validator: (value) {
                      final upi = (value ?? '').trim();
                      final bankAccount = _bankAccountController.text.trim();
                      final bankIfsc = _bankIfscController.text.trim();
                      if (upi.isEmpty && (bankAccount.isEmpty || bankIfsc.isEmpty)) {
                        return 'Enter a UPI ID or complete the bank details below';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('Optional bank fallback'),
                    children: [
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bankAccountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Bank account number',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
                        onChanged: (value) => controller.updateBankDetails(bankAccountNumber: value),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _bankIfscController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'IFSC code',
                          prefixIcon: Icon(Icons.confirmation_number_rounded),
                        ),
                        onChanged: (value) => controller.updateBankDetails(bankIfsc: value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PrimaryActionButton(
                    label: state.isSavingProfile ? 'Saving...' : 'Next',
                    onPressed: state.isSavingProfile ? null : () => unawaited(_saveStep4(controller)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(WorkerOnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final profile = state.profile;
    final selectedCategories = state.categories
        .where((category) => state.draft.selectedCategoryIds.contains(category.id))
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const PremiumSectionHeader(
          title: 'Review and submit',
          subtitle: 'Check everything once before sending your application for review.',
        ),
        const SizedBox(height: 12),
        if (state.submitError != null) ...[
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(state.submitError!)),
                    ],
                  ),
                  if (state.missingFields.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.missingFields.map((field) => _FieldChip(label: field)).toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _SummaryCard(
          title: 'Personal details',
          items: [
            _SummaryItem(label: 'Full name', value: state.draft.fullName),
            _SummaryItem(
              label: 'Date of birth',
              value: state.draft.dateOfBirth == null ? 'Not set' : DateFormat.yMMMMd().format(state.draft.dateOfBirth!),
            ),
            _SummaryItem(label: 'Address', value: state.draft.addressLine1),
            _SummaryItem(label: 'City', value: state.draft.city),
            _SummaryItem(label: 'Pincode', value: state.draft.pincode),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Identity',
          items: [
            _SummaryItem(
              label: 'Aadhaar',
              value: state.draft.savedAadhaarMask ?? profile?.maskedAadhaar() ?? 'Not saved',
            ),
            _SummaryItem(
              label: 'Aadhaar document',
              value: state.draft.aadhaarDocumentFile?.name ?? (profile?.hasAadhaarDoc == true ? 'Uploaded' : 'Not uploaded'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Skills',
          items: [
            _SummaryItem(
              label: 'Selected categories',
              value: selectedCategories.isEmpty ? 'None' : selectedCategories.map((category) => category.name).join(', '),
            ),
            _SummaryItem(
              label: 'Certificates',
              value: state.draft.certificationFiles.isEmpty ? 'Optional' : '${state.draft.certificationFiles.length} uploaded',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Payout details',
          items: [
            _SummaryItem(label: 'UPI ID', value: state.draft.upiId.isEmpty ? 'Not set' : state.draft.upiId),
            _SummaryItem(
              label: 'Bank account',
              value: state.draft.bankAccountNumber.isEmpty ? 'Not set' : state.draft.bankAccountNumber,
            ),
            _SummaryItem(
              label: 'IFSC',
              value: state.draft.bankIfsc.isEmpty ? 'Not set' : state.draft.bankIfsc,
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryActionButton(
          label: state.isSubmitting ? 'Submitting...' : 'Submit for Review',
          onPressed: state.isSubmitting ? null : () => unawaited(_submit(controller)),
        ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.index,
    required this.label,
    required this.active,
    required this.complete,
  });

  final int index;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = active
        ? scheme.primary
        : complete
            ? scheme.secondary.withValues(alpha: 0.18)
            : scheme.surface;
    final foreground = active
        ? Colors.white
        : complete
            ? scheme.secondary
            : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: foreground.withValues(alpha: 0.12),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 11,
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeGlow extends StatelessWidget {
  const _DecorativeGlow({
    required this.color,
    this.size = 170,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _FileTag extends StatelessWidget {
  const _FileTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.error,
            ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.value.isEmpty ? 'Not set' : item.value,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
