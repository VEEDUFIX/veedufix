import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  final _alternatePhoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _upiController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _toolsController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  late PageController _pageController;

  DateTime? _selectedDateOfBirth;
  String? _selectedGender;
  bool _initialized = false;
  bool _seededFromProfile = false;
  int _initialStep = 0;
  bool _editMode = false;
  bool _isScanningDocument = false;
  String? _ocrExtractedText;
  String? _ocrAadhaarCandidate;
  String? _ocrStatusMessage;
  bool _agreementAccepted = false;
  bool _dataConsentAccepted = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _alternatePhoneController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _aadhaarController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _toolsController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
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
    _initialStep = int.tryParse(query['step'] ?? '')?.clamp(0, 7) ?? 0;
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
    _alternatePhoneController.text = profile.alternatePhone ?? '';
    _cityController.text = profile.city ?? '';
    _pincodeController.text = profile.pincode ?? '';
    _aadhaarController.text = '';
    _upiController.text = profile.upiId ?? '';
    _bankAccountController.text = profile.bankAccountNumber ?? '';
    _bankIfscController.text = profile.bankIfsc ?? '';
    _toolsController.text = profile.toolsOwned.join(', ');
    _emergencyContactNameController.text = profile.emergencyContactName ?? '';
    _emergencyContactPhoneController.text = profile.emergencyContactPhone ?? '';
    _selectedDateOfBirth = profile.dateOfBirth;
    _selectedGender = profile.gender;
    _agreementAccepted = profile.agreementAcceptedAt != null;
    _dataConsentAccepted = profile.dataConsentAcceptedAt != null;
    _seededFromProfile = true;
  }

  Future<void> _scanIdentityDocument(XFile file) async {
    if (kIsWeb) {
      setState(() {
        _ocrStatusMessage = 'OCR preview is available on Android and iOS.';
        _ocrExtractedText = null;
        _ocrAadhaarCandidate = null;
      });
      return;
    }

    setState(() {
      _isScanningDocument = true;
      _ocrStatusMessage = 'Scanning document text...';
      _ocrExtractedText = null;
      _ocrAadhaarCandidate = null;
    });

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await recognizer.processImage(inputImage);
      final text = recognizedText.text.trim();
      final candidate = _extractAadhaarCandidate(text);

      if (!mounted) {
        return;
      }

      setState(() {
        _ocrExtractedText = text.isEmpty ? null : text;
        _ocrAadhaarCandidate = candidate;
        _ocrStatusMessage = text.isEmpty
            ? 'No readable text was detected in the image.'
            : 'OCR preview ready. Review the extracted details below.';
        if (candidate != null && _aadhaarController.text.trim().isEmpty) {
          _aadhaarController.text = candidate;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ocrStatusMessage = 'Could not read the document right now. Please try again.';
        _ocrExtractedText = null;
        _ocrAadhaarCandidate = null;
      });
    } finally {
      recognizer.close();
      if (mounted) {
        setState(() => _isScanningDocument = false);
      }
    }
  }

  String? _extractAadhaarCandidate(String text) {
    final normalised = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalised.length < 12) {
      return null;
    }

    for (var i = 0; i <= normalised.length - 12; i++) {
      final candidate = normalised.substring(i, i + 12);
      if (candidate != '000000000000') {
        return '${candidate.substring(0, 4)} ${candidate.substring(4, 8)} ${candidate.substring(8, 12)}';
      }
    }
    return null;
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
      gender: _selectedGender,
      dateOfBirth: _selectedDateOfBirth,
      addressLine1: _addressController.text.trim(),
      alternatePhone: _alternatePhoneController.text.trim(),
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
    if (!_formKeys[2].currentState!.validate()) {
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

  Future<void> _saveStep5(WorkerOnboardingController controller) async {
    final hasAvailability = ref.read(onboardingControllerProvider).profile?.hasAvailability ?? false;
    if (!hasAvailability) {
      await context.push('/availability');
      await controller.refreshStatus();
    }

    if (!(ref.read(onboardingControllerProvider).profile?.hasAvailability ?? false)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set at least one availability slot before continuing.')),
      );
      return;
    }

    controller.nextStep();
  }

  Future<void> _saveStep6(WorkerOnboardingController controller) async {
    if (!_agreementAccepted || !_dataConsentAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the agreement and data consent to continue.')),
      );
      return;
    }

    controller.updateComplianceDetails(
      agreementAccepted: true,
      dataConsentAccepted: true,
    );
    await controller.saveComplianceDetails();
    controller.nextStep();
  }

  Future<void> _saveStep7(WorkerOnboardingController controller) async {
    if (!_formKeys[3].currentState!.validate()) {
      return;
    }

    controller.updateEmergencyContact(
      emergencyContactName: _emergencyContactNameController.text.trim(),
      emergencyContactPhone: _emergencyContactPhoneController.text.trim(),
    );

    await controller.saveEmergencyContact();
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
      case 'availability':
        return 4;
      case 'agreementAcceptedAt':
      case 'dataConsentAcceptedAt':
        return 5;
      case 'emergencyContactName':
      case 'emergencyContactPhone':
        return 6;
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

    final totalSteps = 8;

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
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF13110F),
                            Color(0xFF1B1611),
                            Color(0xFF2A2118),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                        border: Border.all(color: const Color(0xFFC2A15E).withValues(alpha: 0.22)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
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
                                    color: const Color(0xFFC2A15E).withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                                  ),
                                  child: const Icon(
                                    Icons.badge_rounded,
                                    color: Color(0xFFC2A15E),
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
                                                    color: Colors.white,
                                                  ),
                                            ),
                                          ),
                                          if (state.currentStep > 0)
                                            IconButton(
                                              onPressed: state.currentStep == 0
                                                  ? null
                                                  : () => ref.read(onboardingControllerProvider.notifier).previousStep(),
                                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                              tooltip: 'Back',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Complete your profile once and we will handle the rest. Approved workers can start getting jobs quickly.',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.white.withValues(alpha: 0.84),
                                              height: 1.45,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _HeaderBadge(
                                  icon: Icons.save_outlined,
                                  label: 'Auto-saved draft',
                                  accent: Color(0xFFC2A15E),
                                ),
                                _HeaderBadge(
                                  icon: Icons.verified_user_outlined,
                                  label: 'Secure verification',
                                  accent: Color(0xFF0F766E),
                                ),
                                _HeaderBadge(
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
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC2A15E)),
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
                                          color: const Color(0xFFC2A15E),
                                        ),
                                  ),
                                ),
                                Text(
                                  _labelForStep(state.currentStep),
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.78),
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
                        _buildAvailabilityStep(state),
                        _buildComplianceStep(state),
                        _buildEmergencyContactStep(state),
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
      case 4:
        return 'Availability';
      case 5:
        return 'Consent';
      case 6:
        return 'Emergency';
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
        if (state.profile != null) ...[
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account details',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('Phone: ${state.profile?.phone ?? 'Linked to your account'}'),
                  Text('Email: ${state.profile?.email ?? 'Optional'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                      prefixIcon: Icon(Icons.wc_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MALE', child: Text('Male')),
                      DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      DropdownMenuItem(value: 'PREFER_NOT_TO_SAY', child: Text('Prefer not to say')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                      controller.updatePersonalDetails(gender: value);
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
                  TextFormField(
                    controller: _alternatePhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Alternate phone (optional)',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    onChanged: (value) => controller.updatePersonalDetails(alternatePhone: value),
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
    final ocrPreview = _ocrExtractedText;

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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Aadhaar number',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      helperText: savedMask == null ? 'We will only show the last 4 digits after saving.' : 'Saved as $savedMask',
                    ),
                    onChanged: (value) => controller.updateIdentityDetails(aadhaarNumber: value),
                    validator: (value) {
                      if ((value ?? '').trim().length != 12) {
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
                                    unawaited(_scanIdentityDocument(file));
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
                  if (_isScanningDocument || _ocrStatusMessage != null || ocrPreview != null) ...[
                    const SizedBox(height: 16),
                    _OcrPreviewCard(
                      isScanning: _isScanningDocument,
                      statusMessage: _ocrStatusMessage,
                      aadhaarCandidate: _ocrAadhaarCandidate,
                      extractedText: ocrPreview,
                      onUseCandidate: _ocrAadhaarCandidate == null
                          ? null
                          : () {
                              _aadhaarController.text = _ocrAadhaarCandidate!;
                              controller.updateIdentityDetails(aadhaarNumber: _ocrAadhaarCandidate!.replaceAll(' ', ''));
                            },
                    ),
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
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _FieldChip(label: '${category.subcategories.length} subcategories'),
                                  _FieldChip(label: '${category.serviceCount} services'),
                                  if (category.subcategories.isNotEmpty)
                                    _FieldChip(label: category.subcategories.first.name),
                                ],
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
                    if (category.subcategories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...category.subcategories.map(
                        (subcategory) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
                              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subcategory.name,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      '${subcategory.services.length} services',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                                if (subcategory.description != null && subcategory.description!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subcategory.description!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                if (subcategory.services.isEmpty)
                                  Text(
                                    'No services configured yet.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: subcategory.services.map((service) {
                                      final selected = state.draft.selectedServiceIds.contains(service.id);
                                      return FilterChip(
                                        selected: selected,
                                        avatar: Icon(
                                          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          '${service.name} - Rs ${service.startingPrice.toInt()}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onSelected: (value) {
                                          controller.toggleService(service.id, value);
                                        },
                                      );
                                    }).toList(growable: false),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
        const SizedBox(height: 4),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _toolsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Tools you own (optional)',
                hintText: 'Comma separated, for example: drill, ladder, tester',
                prefixIcon: Icon(Icons.build_rounded),
              ),
              onChanged: (value) {
                controller.updateSkillsDetails(
                  toolsOwned: value
                      .split(',')
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toList(growable: false),
                );
              },
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
              key: _formKeys[2],
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(18),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Bank account number',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
                        onChanged: (value) => controller.updateBankDetails(bankAccountNumber: value),
                        validator: (value) {
                          final bank = (value ?? '').trim();
                          if (bank.isNotEmpty && (bank.length < 9 || bank.length > 18)) {
                            return 'Enter a valid bank account number';
                          }
                          return null;
                        },
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

  Widget _buildAvailabilityStep(WorkerOnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final hasAvailability = state.profile?.hasAvailability ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const PremiumSectionHeader(
          title: 'Availability',
          subtitle: 'Set your working days and hours so customers can book you at the right time.',
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAvailability ? 'Availability configured' : 'No weekly schedule saved yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  hasAvailability
                      ? 'Your schedule is already saved. You can review or update it before continuing.'
                      : 'Open the weekly availability screen to select Mon-Sun and your working hours.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await context.push('/availability');
                        await controller.refreshStatus();
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text('Open schedule editor'),
                    ),
                    if (hasAvailability)
                      const _FieldChip(label: 'At least one slot saved'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryActionButton(
          label: 'Next',
          onPressed: state.isSavingProfile ? null : () => unawaited(_saveStep5(controller)),
        ),
      ],
    );
  }

  Widget _buildComplianceStep(WorkerOnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const PremiumSectionHeader(
          title: 'Agreement and consent',
          subtitle: 'These acknowledgements are required before your profile can be submitted.',
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _agreementAccepted,
                  onChanged: (value) {
                    setState(() {
                      _agreementAccepted = value ?? false;
                    });
                    controller.updateComplianceDetails(agreementAccepted: value ?? false);
                  },
                  title: const Text('I agree to the worker agreement'),
                  subtitle: const Text('I have read and accept the worker terms and service rules.'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _dataConsentAccepted,
                  onChanged: (value) {
                    setState(() {
                      _dataConsentAccepted = value ?? false;
                    });
                    controller.updateComplianceDetails(dataConsentAccepted: value ?? false);
                  },
                  title: const Text('I consent to DPDP data processing'),
                  subtitle: const Text('I consent to VeeduFix processing my data for onboarding and operations.'),
                ),
                const SizedBox(height: 8),
                Text(
                  'We store the acceptance timestamps for compliance record-keeping.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryActionButton(
          label: state.isSavingProfile ? 'Saving...' : 'Next',
          onPressed: state.isSavingProfile ? null : () => unawaited(_saveStep6(controller)),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactStep(WorkerOnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const PremiumSectionHeader(
          title: 'Emergency contact',
          subtitle: 'Add a trusted person we can contact if something urgent comes up.',
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
                    controller: _emergencyContactNameController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency contact name',
                      prefixIcon: Icon(Icons.contact_emergency_rounded),
                    ),
                    onChanged: (value) => controller.updateEmergencyContact(emergencyContactName: value),
                    validator: (value) {
                      if ((value ?? '').trim().length < 2) {
                        return 'Enter a contact name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emergencyContactPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Emergency contact phone',
                      prefixIcon: Icon(Icons.phone_in_talk_rounded),
                    ),
                    onChanged: (value) => controller.updateEmergencyContact(emergencyContactPhone: value),
                    validator: (value) {
                      if ((value ?? '').trim().length < 7) {
                        return 'Enter a valid emergency phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  PrimaryActionButton(
                    label: state.isSavingProfile ? 'Saving...' : 'Next',
                    onPressed: state.isSavingProfile ? null : () => unawaited(_saveStep7(controller)),
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
    final selectedServices = state.categories
        .expand((category) => category.subcategories)
        .expand((subcategory) => subcategory.services)
        .where((service) => state.draft.selectedServiceIds.contains(service.id))
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
            _SummaryItem(label: 'Gender', value: state.draft.gender ?? 'Not set'),
            _SummaryItem(
              label: 'Date of birth',
              value: state.draft.dateOfBirth == null ? 'Not set' : DateFormat.yMMMMd().format(state.draft.dateOfBirth!),
            ),
            _SummaryItem(label: 'Address', value: state.draft.addressLine1),
            _SummaryItem(label: 'Alternate phone', value: state.draft.alternatePhone.isEmpty ? 'Not set' : state.draft.alternatePhone),
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
              label: 'Selected services',
              value: selectedServices.isEmpty ? 'None' : selectedServices.map((service) => service.name).join(', '),
            ),
            _SummaryItem(
              label: 'Certificates',
              value: state.draft.certificationFiles.isEmpty ? 'Optional' : '${state.draft.certificationFiles.length} uploaded',
            ),
            _SummaryItem(
              label: 'Tools owned',
              value: state.draft.toolsOwned.isEmpty ? 'Not set' : state.draft.toolsOwned.join(', '),
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
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Availability and compliance',
          items: [
            _SummaryItem(
              label: 'Weekly availability',
              value: state.profile?.hasAvailability == true ? 'Configured' : 'Not set',
            ),
            _SummaryItem(
              label: 'Agreement accepted',
              value: _agreementAccepted ? 'Accepted' : 'Not accepted',
            ),
            _SummaryItem(
              label: 'Data consent',
              value: _dataConsentAccepted ? 'Accepted' : 'Not accepted',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Emergency contact',
          items: [
            _SummaryItem(
              label: 'Name',
              value: _emergencyContactNameController.text.isEmpty ? 'Not set' : _emergencyContactNameController.text,
            ),
            _SummaryItem(
              label: 'Phone',
              value: _emergencyContactPhoneController.text.isEmpty ? 'Not set' : _emergencyContactPhoneController.text,
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

class _OcrPreviewCard extends StatelessWidget {
  const _OcrPreviewCard({
    required this.isScanning,
    required this.statusMessage,
    required this.aadhaarCandidate,
    required this.extractedText,
    this.onUseCandidate,
  });

  final bool isScanning;
  final String? statusMessage;
  final String? aadhaarCandidate;
  final String? extractedText;
  final VoidCallback? onUseCandidate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasCandidate = aadhaarCandidate != null && aadhaarCandidate!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isScanning ? Icons.document_scanner_rounded : Icons.document_scanner_outlined,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OCR preview',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusMessage ?? 'Upload a document to see extracted text here.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isScanning) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 4),
          ],
          if (hasCandidate || extractedText != null) ...[
            const SizedBox(height: 14),
            if (hasCandidate) ...[
              Text(
                'Detected Aadhaar number',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                aadhaarCandidate!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (onUseCandidate != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onUseCandidate,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Use detected number'),
                ),
              ],
            ],
            if (extractedText != null) ...[
              const SizedBox(height: 14),
              Text(
                'Extracted text',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
                ),
                child: Text(
                  extractedText!,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ],
        ],
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
