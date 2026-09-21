import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/worker_logo.dart';
import '../providers/onboarding_provider.dart';

const _ink = Color(0xFF17120D);
const _muted = Color(0xFF756B5D);
const _gold = Color(0xFFC8A75A);
const _cream = Color(0xFFFBF7EF);
const _card = Color(0xFFFFFFFF);
const _line = Color(0xFFE8DDC9);

class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  static const _totalSteps = 14;

  final _pageController = PageController();
  final _formKeys = List.generate(_totalSteps, (_) => GlobalKey<FormState>());
  final _fullName = TextEditingController();
  final _dob = TextEditingController();
  final _whatsapp = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _city = TextEditingController();
  final _areas = TextEditingController();
  final _pincodes = TextEditingController();
  final _travelKm = TextEditingController(text: '8');
  final _aadhaar = TextEditingController();
  final _pan = TextEditingController();
  final _accountHolder = TextEditingController();
  final _bankAccount = TextEditingController();
  final _confirmBankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();
  final _businessName = TextEditingController();
  final _businessAddress = TextEditingController();
  final _gstin = TextEditingController();
  final _visitCharge = TextEditingController(text: 'Platform pricing');
  final Map<String, TextEditingController> _years = {};
  final Map<String, TextEditingController> _expertise = {};
  final Map<String, Set<String>> _skills = {};
  final Map<String, List<String>> _qualifications = {};

  DateTime? _dateOfBirth;
  String? _gender;
  String _language = 'Tamil';
  String _workType = 'Full-time';
  bool _urgentJobs = true;
  bool _hasBusiness = false;
  bool _platformPricing = true;
  bool _infoAccurate = false;
  bool _safetyGuidelines = false;
  bool _termsAccepted = false;
  bool _seeded = false;
  XFile? _profilePhoto;
  XFile? _panDoc;
  XFile? _selfieDoc;
  final Set<String> _workingDays = {'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'};
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 19, minute: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final query = GoRouterState.of(context).uri.queryParameters;
      final step = int.tryParse(query['step'] ?? '')?.clamp(0, _totalSteps - 1) ?? 0;
      ref.read(onboardingControllerProvider.notifier).setStep(step);
      _pageController.jumpToPage(step);
      unawaited(ref.read(onboardingControllerProvider.notifier).bootstrap(
            editMode: query['mode'] == 'edit',
            step: step,
          ));
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _dob,
      _whatsapp,
      _emergencyName,
      _emergencyPhone,
      _city,
      _areas,
      _pincodes,
      _travelKm,
      _aadhaar,
      _pan,
      _accountHolder,
      _bankAccount,
      _confirmBankAccount,
      _ifsc,
      _upi,
      _businessName,
      _businessAddress,
      _gstin,
      _visitCharge,
      ..._years.values,
      ..._expertise.values,
    ]) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _seed(WorkerOnboardingProfile profile) {
    _fullName.text = profile.fullName ?? '';
    _dateOfBirth = profile.dateOfBirth;
    _dob.text = profile.dateOfBirth == null ? '' : DateFormat.yMMMd().format(profile.dateOfBirth!);
    _gender = switch (profile.gender) {
      'MALE' => 'Male',
      'FEMALE' => 'Female',
      'OTHER' => 'Other',
      'PREFER_NOT_TO_SAY' => 'Prefer not to say',
      _ => profile.gender,
    };
    _whatsapp.text = profile.alternatePhone ?? '';
    _emergencyName.text = profile.emergencyContactName ?? '';
    _emergencyPhone.text = profile.emergencyContactPhone ?? '';
    _city.text = profile.city ?? '';
    _pincodes.text = profile.pincode ?? '';
    _upi.text = profile.upiId ?? '';
    final bankAccount = profile.bankAccountNumber ?? '';
    final validBankAccount = RegExp(r'^\d{9,18}$').hasMatch(bankAccount);
    _bankAccount.text = validBankAccount ? bankAccount : '';
    _confirmBankAccount.text = validBankAccount ? bankAccount : '';
    _ifsc.text = profile.bankIfsc ?? '';
    _accountHolder.text = profile.fullName ?? '';
    _infoAccurate = profile.agreementAcceptedAt != null;
    _safetyGuidelines = profile.dataConsentAcceptedAt != null;
    _termsAccepted = profile.agreementAcceptedAt != null;
    _seeded = true;
  }

  Future<void> _next() async {
    final state = ref.read(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final step = state.currentStep;
    FocusScope.of(context).unfocus();
    if (!(_formKeys[step].currentState?.validate() ?? true)) return;

    try {
      if (step == 0 || step == 1 || step == 9 || step == 10) {
        controller.nextStep();
        return;
      }
      if (step == 2) {
        controller.updatePersonalDetails(
          fullName: _fullName.text.trim(),
          gender: _gender?.toUpperCase().replaceAll(' ', '_'),
          dateOfBirth: _dateOfBirth,
          alternatePhone: _whatsapp.text.trim(),
        );
        controller.updateEmergencyContact(
          emergencyContactName: _emergencyName.text.trim(),
          emergencyContactPhone: _emergencyPhone.text.trim(),
        );
        await controller.savePersonalDetails();
        await controller.saveEmergencyContact(
          emergencyContactName: _emergencyName.text.trim(),
          emergencyContactPhone: _emergencyPhone.text.trim(),
        );
        controller.nextStep();
        return;
      }
      if (step == 3) {
        if (state.draft.selectedCategoryIds.isEmpty) {
          _toast('Select at least one service.');
          return;
        }
        await controller.saveSkills();
        controller.nextStep();
        return;
      }
      if (step == 4) {
        controller.updateSkillsDetails(toolsOwned: _experienceSummary(state));
        await controller.saveSkills();
        controller.nextStep();
        return;
      }
      if (step == 5) {
        controller.updatePersonalDetails(
          city: _city.text.trim(),
          pincode: _pincodes.text.trim(),
          addressLine1: [
            _areas.text.trim(),
            '${_travelKm.text.trim()} km radius',
            _workingDays.join(', '),
            '${_from.format(context)}-${_to.format(context)}',
            _workType,
            _urgentJobs ? 'Urgent jobs accepted' : 'No urgent jobs',
          ].where((item) => item.trim().isNotEmpty).join(' | '),
        );
        await controller.savePersonalDetails();
        controller.nextStep();
        return;
      }
      if (step == 6) {
        controller.updateIdentityDetails(aadhaarNumber: _aadhaar.text.trim());
        await controller.savePersonalDetails();
        final file = state.draft.aadhaarDocumentFile;
        if (file != null) await controller.saveIdentityDocument(file);
        controller.nextStep();
        return;
      }
      if (step == 7) {
        await controller.saveSkills();
        controller.nextStep();
        return;
      }
      if (step == 8) {
        if (_bankAccount.text.trim() != _confirmBankAccount.text.trim()) {
          _toast('Bank account numbers do not match.');
          return;
        }
        controller.updateBankDetails(
          bankAccountNumber: _bankAccount.text.trim(),
          bankIfsc: _ifsc.text.trim().toUpperCase(),
          upiId: _upi.text.trim(),
        );
        await controller.saveBankDetails();
        controller.nextStep();
        return;
      }
      if (step == 11) {
        if (!_infoAccurate || !_safetyGuidelines || !_termsAccepted) {
          _toast('Accept the safety declarations.');
          return;
        }
        controller.updateComplianceDetails(agreementAccepted: true, dataConsentAccepted: true);
        await controller.saveComplianceDetails();
        controller.nextStep();
        return;
      }
      if (step == 12) {
        await controller.submitForReview();
        if (mounted) context.go('/onboarding/status');
        return;
      }
      context.go('/worker');
    } catch (error) {
      _toast(_friendlyError(error));
    }
  }

  List<String> _experienceSummary(WorkerOnboardingState state) {
    return _selectedCategories(state).map((category) {
      final skills = _skills[category.id] ?? {};
      final qualifications = _qualifications[category.id] ?? [];
      return [
        category.name,
        if ((_years[category.id]?.text ?? '').trim().isNotEmpty) '${_years[category.id]!.text.trim()} years',
        if (skills.isNotEmpty) 'Skills: ${skills.join(', ')}',
        if (qualifications.isNotEmpty) 'Qualifications: ${qualifications.join(', ')}',
        if ((_expertise[category.id]?.text ?? '').trim().isNotEmpty) _expertise[category.id]!.text.trim(),
      ].join(' - ').substring(0, 500);
    }).toList();
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message']?.toString().trim();
        final issues = data['issues'];
        if (issues is List && issues.isNotEmpty) {
          final details = issues.map((issue) {
            if (issue is Map) {
              final path = issue['path'] ?? issue['field'];
              final detail = issue['message'] ?? issue['error'];
              if (path != null && detail != null) return '$path: $detail';
              return detail?.toString() ?? issue.toString();
            }
            return issue.toString();
          }).join(', ');
          return message == null || message.isEmpty ? details : '$message: $details';
        }
        if (message != null && message.isNotEmpty) return message;
      }
      if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
        return 'Please sign in again to continue.';
      }
    }
    final text = error.toString();
    if (text.contains('401') || text.contains('403')) return 'Please sign in again to continue.';
    if (text.toLowerCase().contains('missing')) return 'Some required details are still missing.';
    return 'Could not save this step. Please try again.';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage(ValueChanged<XFile> onPicked) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 86);
    if (file != null) onPicked(file);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      _dateOfBirth = picked;
      _dob.text = DateFormat.yMMMd().format(picked);
    });
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _from : _to);
    if (picked == null) return;
    setState(() => start ? _from = picked : _to = picked);
  }

  List<CatalogCategory> _catalog(WorkerOnboardingState state) {
    return state.categories.isEmpty ? _fallbackCategories : state.categories;
  }

  List<CatalogCategory> _selectedCategories(WorkerOnboardingState state) {
    return _catalog(state)
        .where((category) => state.draft.selectedCategoryIds.contains(category.id))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    ref.listen<WorkerOnboardingState>(onboardingControllerProvider, (previous, next) {
      if (!_seeded && next.profile != null) _seed(next.profile!);
      if (previous?.currentStep != next.currentStep && _pageController.hasClients) {
        _pageController.animateToPage(
          next.currentStep,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });

    if (state.isLoadingProfile && state.profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(
              currentStep: state.currentStep,
              totalSteps: _totalSteps,
              busy: state.isBusy,
              onBack: state.currentStep == 0
                  ? () => context.go('/login')
                  : () => ref.read(onboardingControllerProvider.notifier).previousStep(),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _screen(0, state, 'Become a Veedufix Partner', 'Get local service jobs, grow your business, and earn with Veedufix.', Icons.engineering_rounded, _welcome()),
                  _screen(1, state, 'Mobile number verified', 'Your OTP sign-in is complete. You can change the number from sign in.', Icons.verified_rounded, _verifiedPhone(state)),
                  _screen(2, state, 'Tell us about yourself', 'Keep this simple. Required fields are marked.', Icons.person_rounded, _basicProfile()),
                  _screen(3, state, 'What services do you provide?', 'Select all services you are qualified to provide.', Icons.grid_view_rounded, _services(state)),
                  _screen(4, state, 'Tell us about your experience', 'Add experience and relevant skills for every selected service.', Icons.workspace_premium_rounded, _experience(state)),
                  _screen(5, state, 'Where and when do you work?', 'Set your service area, pincodes, travel radius, and weekly availability.', Icons.location_on_rounded, _workPreferences()),
                  _screen(6, state, 'Verify your identity', 'We verify partners to keep Veedufix safe and trustworthy.', Icons.security_rounded, _kyc(state)),
                  _screen(7, state, 'Add professional documents', 'Only upload certificates relevant to selected services.', Icons.badge_rounded, _professionalDocs(state)),
                  _screen(8, state, 'Set up your payouts', 'Add bank details so Veedufix can send your earnings.', Icons.account_balance_rounded, _bank()),
                  _screen(9, state, 'Business information', 'Optional. You can continue as an individual worker.', Icons.storefront_rounded, _business()),
                  _screen(10, state, 'Set your service pricing', 'Review platform pricing or add partner charges when enabled.', Icons.currency_rupee_rounded, _pricing()),
                  _screen(11, state, 'Safety & trust', 'Confirm these declarations before profile review.', Icons.health_and_safety_rounded, _safety()),
                  _screen(12, state, 'Review your information', 'Check everything before submitting for verification.', Icons.fact_check_rounded, _review(state)),
                  _screen(13, state, 'Your Partner Profile has been submitted', 'Our team is reviewing your information. We will notify you once verification is complete.', Icons.hourglass_top_rounded, _submitted()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: state.isBusy ? null : _next,
                  child: Text(
                    state.isBusy
                        ? 'Saving...'
                        : state.currentStep == 0
                            ? 'Get Started'
                            : state.currentStep == 12
                                ? 'Submit for Verification'
                                : state.currentStep == 13
                                    ? 'Go to Dashboard'
                                    : 'Continue',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _screen(int step, WorkerOnboardingState state, String title, String subtitle, IconData icon, Widget child) {
    return Form(
      key: _formKeys[step],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _HeroPanel(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 12),
          _SaveBadge(busy: state.isBusy),
        ],
      ),
    );
  }

  Widget _welcome() => _Panel(
        child: Column(
          children: [
            const WorkerLogo(height: 46),
            const SizedBox(height: 18),
            Container(
              height: 148,
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFFFF3D3), borderRadius: BorderRadius.circular(26)),
              child: const Icon(Icons.home_repair_service_rounded, color: _gold, size: 84),
            ),
            const SizedBox(height: 18),
            const _Benefit(icon: Icons.work_rounded, label: 'Get local jobs'),
            const _Benefit(icon: Icons.schedule_rounded, label: 'Flexible working hours'),
            const _Benefit(icon: Icons.groups_rounded, label: 'Grow your customer base'),
            const _Benefit(icon: Icons.verified_rounded, label: 'Secure digital payouts'),
            TextButton(onPressed: () => context.go('/login'), child: const Text('Already registered? Sign In')),
          ],
        ),
      );

  Widget _verifiedPhone(WorkerOnboardingState state) => _Panel(
        child: Column(
          children: [
            const _RoundIcon(icon: Icons.check_rounded, color: Color(0xFF16A34A)),
            const SizedBox(height: 12),
            Text('Mobile number verified', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(state.profile?.phone ?? 'Your mobile number is linked to this account.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Change mobile number'),
            ),
          ],
        ),
      );

  Widget _basicProfile() => _Panel(
        child: Column(
          children: [
            InkWell(
              onTap: () => _pickImage((file) => setState(() => _profilePhoto = file)),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFFFFF3D3),
                child: Icon(_profilePhoto == null ? Icons.add_a_photo_rounded : Icons.check_rounded, color: _gold),
              ),
            ),
            const SizedBox(height: 16),
            _field(_fullName, 'Full name', Icons.person_rounded, validator: _required),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dob,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(labelText: 'Date of birth / age *', prefixIcon: Icon(Icons.cake_rounded)),
              validator: (value) => _adultDate(value, _dateOfBirth),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender *', prefixIcon: Icon(Icons.badge_rounded)),
              items: const ['Male', 'Female', 'Other', 'Prefer not to say'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => _gender = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(labelText: 'Preferred language *', prefixIcon: Icon(Icons.translate_rounded)),
              items: const ['Tamil', 'English', 'Hindi', 'Malayalam', 'Telugu', 'Kannada'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => _language = value ?? _language),
            ),
            const SizedBox(height: 12),
            _field(_whatsapp, 'WhatsApp number (optional)', Icons.chat_rounded, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], requiredMark: false, validator: _optionalPhone),
            const SizedBox(height: 12),
            _field(_emergencyName, 'Emergency contact name', Icons.contact_emergency_rounded, validator: _contactName),
            const SizedBox(height: 12),
            _field(_emergencyPhone, 'Emergency contact number', Icons.phone_rounded, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], validator: _phone),
          ],
        ),
      );

  Widget _services(WorkerOnboardingState state) {
    final categories = _catalog(state);
    return Column(
      children: [
        if (state.isLoadingCategories) const LinearProgressIndicator(),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.02,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final selected = state.draft.selectedCategoryIds.contains(category.id);
            return _ServiceCard(
              title: category.name,
              icon: _iconFor(category),
              selected: selected,
              onTap: () => ref.read(onboardingControllerProvider.notifier).toggleCategory(category.id, !selected),
            );
          },
        ),
        const SizedBox(height: 14),
        ..._selectedCategories(state).map((category) => _SkillPreview(title: category.name, skills: _skillsFor(category))),
      ],
    );
  }

  Widget _experience(WorkerOnboardingState state) {
    final categories = _selectedCategories(state);
    if (categories.isEmpty) return const _Panel(child: Text('Select services first.'));
    return Column(
      children: categories.map((category) {
        final years = _years.putIfAbsent(category.id, TextEditingController.new);
        final expertise = _expertise.putIfAbsent(category.id, TextEditingController.new);
        final selectedSkills = _skills.putIfAbsent(category.id, () => <String>{});
        final qualifications = _qualifications.putIfAbsent(category.id, () => <String>[]);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                _field(years, 'Years of experience', Icons.timeline_rounded, keyboardType: TextInputType.number, validator: _required),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skillsFor(category).map((skill) {
                    return FilterChip(
                      label: Text(skill),
                      selected: selectedSkills.contains(skill),
                      onSelected: (value) => setState(() => value ? selectedSkills.add(skill) : selectedSkills.remove(skill)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: expertise,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Tell customers about your expertise *', prefixIcon: Icon(Icons.description_rounded)),
                  validator: (value) => (value ?? '').trim().length < 10 ? 'Add a short expertise note' : null,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...qualifications.map((item) => Chip(label: Text(item))),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add qualification'),
                      onPressed: () => setState(() => qualifications.add('Certificate ${qualifications.length + 1}')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _workPreferences() => _Panel(
        child: Column(
          children: [
            _field(_city, 'City', Icons.location_city_rounded, validator: _required),
            const SizedBox(height: 12),
            _field(_areas, 'Areas/localities served', Icons.map_rounded, validator: _required),
            const SizedBox(height: 12),
            _field(_pincodes, 'Service pincodes', Icons.pin_drop_rounded, keyboardType: TextInputType.number, validator: _required),
            const SizedBox(height: 12),
            _field(_travelKm, 'Maximum travel distance (km)', Icons.route_rounded, keyboardType: TextInputType.number, validator: _required),
            const SizedBox(height: 16),
            _sectionTitle('Working days'),
            Wrap(
              spacing: 8,
              children: const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((day) {
                return FilterChip(
                  label: Text(day),
                  selected: _workingDays.contains(day),
                  onSelected: (_) => setState(() => _workingDays.contains(day) ? _workingDays.remove(day) : _workingDays.add(day)),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(true), icon: const Icon(Icons.schedule_rounded), label: Text(_from.format(context)))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(false), icon: const Icon(Icons.schedule_rounded), label: Text(_to.format(context)))),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              selected: {_workType},
              segments: const [
                ButtonSegment(value: 'Full-time', label: Text('Full-time')),
                ButtonSegment(value: 'Part-time', label: Text('Part-time')),
              ],
              onSelectionChanged: (value) => setState(() => _workType = value.first),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _urgentJobs,
              onChanged: (value) => setState(() => _urgentJobs = value),
              title: const Text('Emergency / urgent jobs'),
            ),
          ],
        ),
      );

  Widget _kyc(WorkerOnboardingState state) => _Panel(
        child: Column(
          children: [
            _field(_aadhaar, 'Aadhaar / accepted ID number', Icons.credit_card_rounded, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: _required),
            const SizedBox(height: 12),
            _field(_pan, 'PAN (optional)', Icons.badge_outlined, requiredMark: false),
            const SizedBox(height: 12),
            _UploadTile(
              title: 'Identity Proof',
              subtitle: 'Required for secure verification',
              uploaded: state.draft.aadhaarDocumentFile != null || state.profile?.hasAadhaarDoc == true,
              onTap: () => _pickImage((file) => ref.read(onboardingControllerProvider.notifier).setAadhaarDocumentFile(file)),
            ),
            _UploadTile(title: 'PAN', subtitle: 'Used for payouts when required', uploaded: _panDoc != null, onTap: () => _pickImage((file) => setState(() => _panDoc = file))),
            _UploadTile(title: 'Selfie Verification', subtitle: 'Helps us confirm the account holder', uploaded: _selfieDoc != null, onTap: () => _pickImage((file) => setState(() => _selfieDoc = file))),
            const _InfoBox(text: 'Your documents are securely stored and used for verification purposes.', icon: Icons.lock_rounded),
          ],
        ),
      );

  Widget _professionalDocs(WorkerOnboardingState state) {
    final required = _selectedCategories(state).where(_needsCertificate).toList();
    if (required.isEmpty) {
      return const _Panel(child: Column(children: [Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 42), SizedBox(height: 10), Text('Nothing required for your selected services.'), Text('You can skip for now.')]));
    }
    return Column(
      children: required.map((category) {
        return _UploadTile(
          title: '${category.name} certification',
          subtitle: 'Upload only if this service requires proof',
          uploaded: state.draft.certificationFiles.containsKey(category.id) || state.draft.certificationUrls[category.id] == true,
          onTap: () => ref.read(onboardingControllerProvider.notifier).pickAndSetCertificationFile(category.id),
        );
      }).toList(),
    );
  }

  Widget _bank() => _Panel(
        child: Column(
          children: [
            _field(_accountHolder, 'Account holder name', Icons.person_pin_rounded, validator: _required),
            const SizedBox(height: 12),
            _field(_bankAccount, 'Bank account number', Icons.account_balance_rounded, keyboardType: TextInputType.number, validator: _bankAccountValidator),
            const SizedBox(height: 12),
            _field(_confirmBankAccount, 'Confirm account number', Icons.check_circle_outline_rounded, keyboardType: TextInputType.number, validator: _required),
            const SizedBox(height: 12),
            _field(_ifsc, 'IFSC', Icons.numbers_rounded, validator: _required),
            const SizedBox(height: 12),
            _field(_upi, 'UPI ID (optional)', Icons.payments_rounded, requiredMark: false),
            const SizedBox(height: 12),
            const _InfoBox(text: 'Bank account name may be checked against verified identity.', icon: Icons.verified_user_rounded),
          ],
        ),
      );

  Widget _business() => _Panel(
        child: Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _hasBusiness,
              onChanged: (value) => setState(() => _hasBusiness = value),
              title: const Text('I operate as a registered business'),
              subtitle: const Text('No business registration? You can continue.'),
            ),
            if (_hasBusiness) ...[
              const SizedBox(height: 12),
              _field(_businessName, 'Business name', Icons.store_rounded, requiredMark: false),
              const SizedBox(height: 12),
              _field(_businessAddress, 'Business address', Icons.location_on_rounded, requiredMark: false),
              const SizedBox(height: 12),
              _field(_gstin, 'GSTIN (optional)', Icons.receipt_long_rounded, requiredMark: false),
            ],
          ],
        ),
      );

  Widget _pricing() => _Panel(
        child: Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _platformPricing,
              onChanged: (value) => setState(() => _platformPricing = value),
              title: const Text('Use Veedufix platform pricing'),
              subtitle: const Text('Recommended. Customers see admin-defined charges.'),
            ),
            if (_platformPricing)
              const _InfoBox(text: 'Customers will see the applicable service charges before booking.', icon: Icons.currency_rupee_rounded)
            else
              _field(_visitCharge, 'Base visit / service charge', Icons.currency_rupee_rounded, keyboardType: TextInputType.number, requiredMark: false),
          ],
        ),
      );

  Widget _safety() => _Panel(
        child: Column(
          children: [
            _check('I confirm that the information provided is accurate.', _infoAccurate, (value) => setState(() => _infoAccurate = value)),
            _check('I agree to follow Veedufix safety guidelines.', _safetyGuidelines, (value) => setState(() => _safetyGuidelines = value)),
            _check('I agree to the Partner Terms & Conditions.', _termsAccepted, (value) => setState(() => _termsAccepted = value)),
            const _InfoBox(text: 'Background verification or references may be requested before approval.', icon: Icons.health_and_safety_rounded),
          ],
        ),
      );

  Widget _review(WorkerOnboardingState state) => Column(
        children: [
          _Summary(title: 'Personal Information', onEdit: () => ref.read(onboardingControllerProvider.notifier).setStep(2), rows: {'Name': _fullName.text, 'Mobile': state.profile?.phone ?? 'Linked', 'Language': _language}),
          _Summary(title: 'Services', onEdit: () => ref.read(onboardingControllerProvider.notifier).setStep(3), rows: {'Selected': _selectedCategories(state).map((e) => e.name).join(', ')}),
          _Summary(title: 'Service Area', onEdit: () => ref.read(onboardingControllerProvider.notifier).setStep(5), rows: {'City': _city.text, 'Pincodes': _pincodes.text, 'Days': _workingDays.join(', ')}),
          _Summary(title: 'Verification', onEdit: () => ref.read(onboardingControllerProvider.notifier).setStep(6), rows: {'Identity': state.profile?.hasAadhaarDoc == true ? 'Uploaded' : 'Pending', 'PAN': _panDoc == null ? 'Optional' : 'Uploaded'}),
          _Summary(title: 'Payment', onEdit: () => ref.read(onboardingControllerProvider.notifier).setStep(8), rows: {'Bank': _bankAccount.text.isEmpty ? 'Not set' : 'Added'}),
        ],
      );

  Widget _submitted() => const _Panel(
        child: Column(
          children: [
            _Timeline(done: true, label: 'Profile completed'),
            _Timeline(done: true, label: 'Documents submitted'),
            _Timeline(active: true, label: 'Verification in progress'),
            _Timeline(label: 'Partner approval'),
            _Timeline(label: 'Ready for jobs'),
          ],
        ),
      );

  Widget _check(String text, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: (value) => onChanged(value ?? false),
      title: Text(text),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.currentStep, required this.totalSteps, required this.busy, required this.onBack});
  final int currentStep;
  final int totalSteps;
  final bool busy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final percent = ((currentStep + 1) / totalSteps * 100).round();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 20, 14),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Profile Completion $percent%', style: const TextStyle(fontWeight: FontWeight.w900))),
                      _SaveBadge(busy: busy, compact: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Step ${currentStep + 1} of $totalSteps', style: const TextStyle(color: _muted)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: (currentStep + 1) / totalSteps, minHeight: 7, color: _gold, backgroundColor: const Color(0xFFF0E7D8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 22, offset: const Offset(0, 12))]),
      child: Row(
        children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: _ink)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.08)),
                const SizedBox(height: 8),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 10))]),
      child: child,
    );
  }
}

class _SaveBadge extends StatelessWidget {
  const _SaveBadge({required this.busy, this.compact = false});
  final bool busy;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 6),
      decoration: BoxDecoration(color: (busy ? Colors.blue : Colors.green).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(busy ? Icons.sync_rounded : Icons.cloud_done_outlined, size: 14, color: busy ? Colors.blue : Colors.green),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(busy ? 'Saving...' : 'Saved', style: TextStyle(color: busy ? Colors.blue : Colors.green, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Icon(icon, color: _gold), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))]),
      );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.title, required this.icon, required this.selected, required this.onTap});
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: selected ? _ink : _card, borderRadius: BorderRadius.circular(22), border: Border.all(color: selected ? _gold : _line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: selected ? _gold : _muted, size: 30), const Spacer(), Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : _ink, fontWeight: FontWeight.w900))]),
        ),
      );
}

class _SkillPreview extends StatelessWidget {
  const _SkillPreview({required this.title, required this.skills});
  final String title;
  final List<String> skills;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$title skills', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: skills.map((e) => Chip(label: Text(e))).toList())])),
      );
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.title, required this.subtitle, required this.uploaded, required this.onTap});
  final String title;
  final String subtitle;
  final bool uploaded;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          child: Row(children: [Icon(uploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])), Text(uploaded ? 'Uploaded' : 'Upload')]),
        ),
      );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF6E5), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [Icon(icon, color: _gold), const SizedBox(width: 10), Expanded(child: Text(text))]),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.title, required this.rows, required this.onEdit});
  final String title;
  final Map<String, String> rows;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))), TextButton(onPressed: onEdit, child: const Text('Edit'))]),
            ...rows.entries.map((entry) => Padding(padding: const EdgeInsets.only(top: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 92, child: Text(entry.key, style: const TextStyle(color: _muted))), Expanded(child: Text(entry.value.isEmpty ? 'Not set' : entry.value, style: const TextStyle(fontWeight: FontWeight.w800)))]))),
          ]),
        ),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.label, this.done = false, this.active = false});
  final String label;
  final bool done;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF16A34A) : active ? _gold : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [Icon(done ? Icons.check_circle_rounded : active ? Icons.hourglass_top_rounded : Icons.radio_button_unchecked_rounded, color: color), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))]),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: 34, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 34));
}

TextFormField _field(
  TextEditingController controller,
  String label,
  IconData icon, {
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator,
  bool requiredMark = true,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(labelText: requiredMark ? '$label *' : label, prefixIcon: Icon(icon)),
    validator: validator,
  );
}

String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Required' : null;
String? _bankAccountValidator(String? value) {
  return RegExp(r'^\d{9,18}$').hasMatch((value ?? '').trim())
      ? null
      : 'Enter 9 to 18 digits';
}
String? _contactName(String? value) => (value ?? '').trim().length < 2 ? 'Enter at least 2 characters' : null;
String? _adultDate(String? value, DateTime? dob) {
  if ((value ?? '').trim().isEmpty) return 'Required';
  if (dob == null) return 'Select a valid date of birth';
  final today = DateTime.now();
  var age = today.year - dob.year;
  if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
  return age < 18 ? 'You must be at least 18 years old' : null;
}
String? _phone(String? value) => (value ?? '').length != 10 ? 'Enter a valid 10-digit phone number' : null;
String? _optionalPhone(String? value) => (value ?? '').isEmpty || value!.length == 10 ? null : 'Enter a valid 10-digit phone number';

IconData _iconFor(CatalogCategory category) {
  final text = '${category.slug} ${category.name}'.toLowerCase();
  if (text.contains('electric')) return Icons.electrical_services_rounded;
  if (text.contains('plumb')) return Icons.plumbing_rounded;
  if (text.contains('ac')) return Icons.ac_unit_rounded;
  if (text.contains('appliance')) return Icons.kitchen_rounded;
  if (text.contains('clean')) return Icons.cleaning_services_rounded;
  if (text.contains('paint')) return Icons.format_paint_rounded;
  if (text.contains('carpenter')) return Icons.carpenter_rounded;
  if (text.contains('water') || text.contains('ro')) return Icons.water_drop_rounded;
  if (text.contains('pest')) return Icons.pest_control_rounded;
  return Icons.handyman_rounded;
}

List<String> _skillsFor(CatalogCategory category) {
  final text = '${category.slug} ${category.name}'.toLowerCase();
  if (text.contains('electric')) return const ['Wiring', 'Fan installation', 'Light installation', 'Switch/socket installation', 'MCB repair', 'Electrical troubleshooting'];
  if (text.contains('plumb')) return const ['Pipe repair', 'Tap installation', 'Bathroom plumbing', 'Leakage repair', 'Drain cleaning', 'Water tank work'];
  if (text.contains('ac')) return const ['AC installation', 'AC servicing', 'Gas charging', 'AC repair', 'General maintenance'];
  if (text.contains('clean')) return const ['Deep cleaning', 'Bathroom cleaning', 'Kitchen cleaning', 'Move-in cleaning'];
  if (text.contains('paint')) return const ['Wall painting', 'Waterproofing', 'Putty work', 'Texture painting'];
  if (text.contains('carpenter')) return const ['Door repair', 'Furniture assembly', 'Cabinet work', 'Lock fitting'];
  if (text.contains('pest')) return const ['General pest control', 'Termite treatment', 'Cockroach treatment'];
  return const ['Inspection', 'Repair', 'Installation', 'Maintenance'];
}

bool _needsCertificate(CatalogCategory category) {
  final text = '${category.slug} ${category.name}'.toLowerCase();
  return text.contains('electric') || text.contains('ac') || text.contains('pest') || text.contains('water') || text.contains('ro');
}

const _fallbackCategories = <CatalogCategory>[
  CatalogCategory(id: 'electrician', name: 'Electrician', slug: 'electrician'),
  CatalogCategory(id: 'plumber', name: 'Plumber', slug: 'plumber'),
  CatalogCategory(id: 'ac-repair', name: 'AC Repair & Service', slug: 'ac-repair'),
  CatalogCategory(id: 'appliance-repair', name: 'Appliance Repair', slug: 'appliance-repair'),
  CatalogCategory(id: 'cleaning', name: 'Cleaning', slug: 'cleaning'),
  CatalogCategory(id: 'painting', name: 'Painting', slug: 'painting'),
  CatalogCategory(id: 'carpenter', name: 'Carpenter', slug: 'carpenter'),
  CatalogCategory(id: 'ro-water-purifier', name: 'RO / Water Purifier Service', slug: 'ro-water-purifier'),
  CatalogCategory(id: 'pest-control', name: 'Pest Control', slug: 'pest-control'),
  CatalogCategory(id: 'other', name: 'Other', slug: 'other'),
];
