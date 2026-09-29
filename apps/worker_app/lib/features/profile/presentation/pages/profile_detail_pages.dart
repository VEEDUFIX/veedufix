import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/worker_profile_providers.dart';

const _gold = Color(0xFFC8A75A);
const _ink = Color(0xFF17120D);
const _muted = Color(0xFF766F66);
const _cream = Color(0xFFFBF7EF);

class KycVerificationPage extends ConsumerWidget {
  const KycVerificationPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ProfileDetailScaffold(
      title: 'KYC & Verification',
      child: Column(children: [
        _profileBody(ref, (profile) {
          final status =
              _text(profile['verificationStatus'], 'PENDING').toUpperCase();
          final verified = status == 'VERIFIED';
          final rejected = status == 'REJECTED';
          return Column(children: [
            _StatusCard(
                title: verified
                    ? 'Your identity has been verified.'
                    : rejected
                        ? 'Action required: your verification was rejected.'
                        : 'Verification is under review.',
                icon: verified
                    ? Icons.verified_rounded
                    : rejected
                        ? Icons.warning_amber_rounded
                        : Icons.hourglass_top_rounded,
                color: verified
                    ? Colors.green
                    : rejected
                        ? Colors.red
                        : _gold),
            if (rejected && _text(profile['rejectionReason'], '').isNotEmpty)
              _DetailSection(title: 'Review note', children: [
                _DetailRow(
                    label: 'Reason',
                    value: _text(profile['rejectionReason'], ''),
                    icon: Icons.info_outline_rounded)
              ]),
          ]);
        }),
        _documentsList(context, ref, professionalOnly: false),
        const _DetailSection(title: 'Selfie verification', children: [
          _DetailRow(
              label: 'Status',
              value: 'Requested only if needed during review',
              icon: Icons.face_rounded)
        ]),
        const _SecurityNote(
            text:
                'Your documents are securely stored and used only for verification purposes.'),
      ]),
    );
  }
}

class ExperienceSkillsPage extends ConsumerWidget {
  const ExperienceSkillsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ProfileDetailScaffold(
      title: 'Experience & Skills',
      child: _profileBody(ref, (profile) {
        final skills = _skills(profile);
        return Column(children: [
          _DetailSection(title: 'Professional experience', children: [
            _DetailRow(
                label: 'Years of experience',
                value: '${profile['experienceYears'] ?? 0} years',
                icon: Icons.timeline_rounded),
            _DetailRow(
                label: 'Primary service',
                value: skills.isEmpty ? 'Not selected' : skills.first,
                icon: Icons.home_repair_service_rounded)
          ]),
          _DetailSection(title: 'Skills', children: [
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.isEmpty
                    ? [const Chip(label: Text('Add your skills'))]
                    : skills.map((s) => Chip(label: Text(s))).toList())
          ]),
          const _DetailSection(title: 'Qualifications', children: [
            _DetailRow(
                label: 'Certifications',
                value: 'Add qualification',
                icon: Icons.workspace_premium_rounded)
          ]),
          _PrimaryAction(
              label: 'Edit experience',
              onPressed: () => context.push('/profile/edit')),
        ]);
      }));
}

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ProfileDetailScaffold(
      title: 'My Services',
      child: _profileBody(ref, (profile) {
        final skills = _skills(profile);
        return Column(children: [
          if (skills.isEmpty)
            const _EmptyCard(
                title: 'No services added',
                subtitle: 'Add the services you are qualified to provide.'),
          ...skills
              .map((service) => _DetailSection(title: service, children: const [
                    _DetailRow(
                        label: 'Status',
                        value: 'Selected for your partner profile',
                        icon: Icons.home_repair_service_rounded)
                  ])),
          _PrimaryAction(
              label: 'Request a service update',
              onPressed: () => context.push(
                  '/support?autoFocusForm=true&category=app&subject=Service%20profile%20update&message=Please%20help%20me%20add%20or%20change%20a%20service%20on%20my%20partner%20profile.')),
        ]);
      }));
}

class PortfolioPage extends ConsumerStatefulWidget {
  const PortfolioPage({super.key});

  @override
  ConsumerState<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends ConsumerState<PortfolioPage> {
  bool _uploading = false;
  String? _error;

  Future<void> _addPhoto(String workerId) async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (file == null || !mounted) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref
          .read(workerProfileRepositoryProvider)
          .uploadPortfolioPhoto(file.path, file.name);
      ref.invalidate(workerPublicProfileProvider(workerId));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ProfileDetailScaffold(
        title: 'My Portfolio',
        child: ref.watch(workerAccountProfileProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _EmptyCard(
                  title: 'Could not load your profile',
                  subtitle: error.toString()),
              data: (account) {
                final user = account['user'] is Map<String, dynamic>
                    ? account['user'] as Map<String, dynamic>
                    : const <String, dynamic>{};
                final profile = user['workerProfile'] is Map<String, dynamic>
                    ? user['workerProfile'] as Map<String, dynamic>
                    : const <String, dynamic>{};
                final workerId = _text(profile['id'], '');
                if (workerId.isEmpty) {
                  return const _EmptyCard(
                      title: 'Portfolio unavailable',
                      subtitle:
                          'Complete your partner profile before adding work samples.');
                }
                final publicProfile =
                    ref.watch(workerPublicProfileProvider(workerId));
                return Column(children: [
                  _PrimaryAction(
                      label: _uploading ? 'Uploading...' : 'Add work photo',
                      onPressed:
                          _uploading ? () {} : () => _addPhoto(workerId)),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                  const SizedBox(height: 12),
                  publicProfile.when(
                    loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()),
                    error: (error, _) => _EmptyCard(
                        title: 'Could not load portfolio',
                        subtitle: error.toString()),
                    data: (profile) => profile.portfolioPhotos.isEmpty
                        ? const _EmptyCard(
                            title: 'Show customers what you can do.',
                            subtitle:
                                'Add photos of your completed work and before/after projects.')
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: profile.portfolioPhotos.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10),
                            itemBuilder: (context, index) => ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                  profile.portfolioPhotos[index].url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                          color: Colors.black12,
                                          child: Icon(
                                              Icons.broken_image_outlined))),
                            ),
                          ),
                  ),
                ]);
              },
            ),
      );
}

class ServiceAreaPage extends ConsumerWidget {
  const ServiceAreaPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ProfileDetailScaffold(
      title: 'Service Area',
      child: _profileBody(
          ref,
          (profile) => Column(children: [
                _DetailSection(title: 'Coverage', children: [
                  _DetailRow(
                      label: 'City',
                      value: _text(profile['city'], 'Not set'),
                      icon: Icons.location_city_rounded),
                  _DetailRow(
                      label: 'Localities',
                      value: _text(profile['serviceAreas'], 'Not set'),
                      icon: Icons.map_rounded),
                  _DetailRow(
                      label: 'Pincode',
                      value: _text(profile['pincode'], 'Not set'),
                      icon: Icons.pin_drop_rounded),
                  _DetailRow(
                      label: 'Travel distance',
                      value: '${_text(profile['serviceRadiusKm'], '10')} km',
                      icon: Icons.social_distance_rounded)
                ]),
                const _SecurityNote(
                    text:
                        'Customers outside your service area may not be able to book you.'),
                _PrimaryAction(
                    label: 'Request a service area update',
                    onPressed: () => context.push(
                        '/support?autoFocusForm=true&category=account&subject=${Uri.encodeComponent('Service area update')}&message=${Uri.encodeComponent('Please help me update the city, localities, pincode, or travel distance on my partner profile.')}')),
              ])));
}

class ProfessionalDocumentsPage extends StatelessWidget {
  const ProfessionalDocumentsPage({super.key});
  @override
  Widget build(BuildContext context) => _ProfileDetailScaffold(
      title: 'Professional Documents',
      child: Consumer(
          builder: (context, ref, _) => Column(children: [
                _documentsList(context, ref, professionalOnly: true),
                _PrimaryAction(
                    label: 'Upload document',
                    onPressed: () => context.push('/documents/upload')),
              ])));
}

Widget _documentsList(BuildContext context, WidgetRef ref,
    {required bool professionalOnly}) {
  return ref.watch(workerDocumentsProvider).when(
        loading: () => const Padding(
            padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
        error: (error, _) => _EmptyCard(
            title: 'Could not load documents', subtitle: error.toString()),
        data: (docs) {
          final visible = professionalOnly
              ? docs
                  .where((doc) => !const {
                        'aadhaar',
                        'pan',
                        'passport',
                        'voter_id',
                        'driving_license'
                      }.contains((doc['type'] ?? '').toString().toLowerCase()))
                  .toList()
              : docs;
          if (visible.isEmpty) {
            return const _EmptyCard(
                title: 'No additional documents required',
                subtitle:
                    'Documents relevant to your services will appear here after upload.');
          }
          return _DetailSection(
            title: professionalOnly
                ? 'Professional documents'
                : 'Submitted documents',
            children: visible.map((doc) {
              final status = doc['rejectedAt'] != null
                  ? 'Action required'
                  : doc['verifiedAt'] != null
                      ? 'Verified'
                      : 'Under review';
              final icon = status == 'Verified'
                  ? Icons.verified_rounded
                  : status == 'Action required'
                      ? Icons.warning_amber_rounded
                      : Icons.hourglass_top_rounded;
              return _DetailRow(
                  label: (doc['type'] ?? 'Document')
                      .toString()
                      .replaceAll('_', ' ')
                      .toUpperCase(),
                  value: status,
                  icon: icon,
                  action: status == 'Action required'
                      ? () => context.push('/documents/upload')
                      : null);
            }).toList(growable: false),
          );
        },
      );
}

class ServicePreferencesPage extends ConsumerWidget {
  const ServicePreferencesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ProfileDetailScaffold(
        title: 'Service Preferences',
        child: _profileBody(ref, (profile) {
          final slots = _availabilitySlots(profile['availabilitySlots']);
          final radius = profile['serviceRadiusKm'];
          final emergency = profile['acceptsUrgentJobs'];
          return Column(children: [
            _DetailSection(
              title: 'Job matching',
              children: [
                _DetailRow(
                  label: 'Emergency jobs',
                  value: emergency is bool
                      ? (emergency ? 'Enabled' : 'Disabled')
                      : 'Not set',
                  icon: Icons.emergency_rounded,
                ),
                _DetailRow(
                  label: 'Weekly schedule',
                  value: _availabilitySummary(slots),
                  icon: Icons.schedule_rounded,
                ),
                _DetailRow(
                  label: 'Work preference',
                  value: switch (profile['workType']) {
                    'PART_TIME' => 'Part-time',
                    'FULL_TIME' => 'Full-time',
                    _ => 'Not set',
                  },
                  icon: Icons.work_outline_rounded,
                ),
                _DetailRow(
                  label: 'Travel distance',
                  value: radius is num ? '${radius.toInt()} km' : 'Not set',
                  icon: Icons.social_distance_rounded,
                ),
              ],
            ),
            const _SecurityNote(
              text:
                  'These saved preferences help match you with suitable jobs.',
            ),
            _PrimaryAction(
              label: 'Manage availability',
              onPressed: () => context.push('/availability'),
            ),
          ]);
        }),
      );
}

class BankDetailsPage extends ConsumerWidget {
  const BankDetailsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ProfileDetailScaffold(
      title: 'Payout Details',
      child: _profileBody(ref, (profile) {
        final account = _text(profile['bankAccountNumber'], 'Not added');
        final ifsc = _text(profile['bankIfsc'], 'Not added');
        final upi = _text(profile['upiId'], 'Not added');
        final hasBank = account != 'Not added' && ifsc != 'Not added';
        return Column(children: [
          const Text('Manage where your Veedufix earnings are paid.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 16),
          _StatusCard(
              title: hasBank
                  ? 'Bank details on file'
                  : (upi != 'Not added'
                      ? 'UPI details on file'
                      : 'Payout details not added'),
              icon: hasBank || upi != 'Not added'
                  ? Icons.account_balance_rounded
                  : Icons.warning_amber_rounded,
              color: hasBank || upi != 'Not added' ? _gold : _muted),
          _DetailSection(title: 'Payout account', children: [
            _DetailRow(
                label: 'Account holder',
                value: _text(profile['bankAccountHolderName'],
                    _text(profile['fullName'], 'Not set')),
                icon: Icons.person_rounded),
            _DetailRow(
                label: 'Account',
                value: hasBank ? _maskAccount(account) : 'Not added',
                icon: Icons.account_balance_rounded),
            _DetailRow(
                label: 'IFSC',
                value: hasBank ? _maskIfsc(ifsc) : 'Not added',
                icon: Icons.code_rounded),
            _DetailRow(
                label: 'UPI ID',
                value: upi == 'Not added' ? upi : _maskUpi(upi),
                icon: Icons.alternate_email_rounded),
            const _DetailRow(
                label: 'Verification',
                value: 'Status not provided by the server',
                icon: Icons.info_outline_rounded)
          ]),
          _PrimaryAction(
              label: 'Change payout account',
              onPressed: () => context.push('/profile/payout-change')),
          const SizedBox(height: 12),
          const _SecurityNote(
              text:
                  'Your payout information is securely protected and used only to process your earnings.'),
        ]);
      }));
}

class ChangePayoutAccountPage extends ConsumerWidget {
  const ChangePayoutAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _ProfileDetailScaffold(
        title: 'Change payout account',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StatusCard(
              title: 'Account changes need secure verification',
              icon: Icons.shield_outlined,
              color: _gold,
            ),
            const SizedBox(height: 12),
            const Text(
              'Bank verification is not available in the app yet. Your current payout details have not changed.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            _PrimaryAction(
              label: 'Contact support',
              onPressed: () => context.push(
                '/support?autoFocusForm=true&category=payment&subject=Payout%20account%20change&message=I%20need%20help%20changing%20my%20payout%20account.%20Please%20verify%20my%20request%20securely.',
              ),
            ),
          ],
        ),
      );
}

class PaymentDetailsPage extends ConsumerWidget {
  const PaymentDetailsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ProfileDetailScaffold(
      title: 'Payment Details',
      child: _profileBody(ref, (profile) {
        final account = _text(profile['bankAccountNumber'], '');
        final upi = _text(profile['upiId'], '');
        final hasBank =
            account.isNotEmpty && _text(profile['bankIfsc'], '').isNotEmpty;
        final method = [
          if (hasBank) 'Bank transfer',
          if (upi.isNotEmpty) 'UPI wallet withdrawal'
        ].join(' and ');
        return Column(children: [
          _DetailSection(title: 'Payout setup', children: [
            _DetailRow(
                label: 'Setup',
                value: method.isEmpty
                    ? 'No payout details on file'
                    : 'Details on file; verification status unavailable',
                icon: method.isEmpty
                    ? Icons.info_outline_rounded
                    : Icons.account_balance_rounded),
            if (hasBank)
              _DetailRow(
                  label: 'Bank account',
                  value: 'Ending ${_lastFour(account)}',
                  icon: Icons.account_balance_rounded),
            if (upi.isNotEmpty)
              _DetailRow(
                  label: 'UPI',
                  value: _maskUpi(upi),
                  icon: Icons.alternate_email_rounded),
          ]),
          _PrimaryAction(
              label: 'View Earnings', onPressed: () => context.go('/earnings')),
        ]);
      }));
}

class AccountStatusPage extends ConsumerWidget {
  const AccountStatusPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _ProfileDetailScaffold(
      title: 'Account Status',
      child: _profileBody(ref, (profile) {
        final items = <(String, bool, String)>[
          (
            'Mobile verified',
            profile['_phoneVerified'] == true,
            '/profile/edit'
          ),
          (
            'Identity verified',
            profile['verificationStatus'] == 'VERIFIED',
            '/profile/kyc'
          ),
          ('Services added', _skills(profile).isNotEmpty, '/profile/services'),
          (
            'Service area added',
            _text(profile['city'], '') != '',
            '/profile/service-area'
          ),
          (
            'Payout details added',
            _text(profile['bankAccountNumber'], '') != '' ||
                _text(profile['upiId'], '') != '',
            '/profile/bank-details'
          ),
          (
            'Availability configured',
            profile['hasAvailability'] == true,
            '/availability'
          ),
        ];
        return _DetailSection(
            title: 'Completion checklist',
            children: items
                .map((item) => _DetailRow(
                    label: item.$1,
                    value: item.$2 ? 'Complete' : 'Action required',
                    icon: item.$2
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    action: item.$2 ? null : () => context.push(item.$3)))
                .toList());
      }));
}

Widget _profileBody(
    WidgetRef ref, Widget Function(Map<String, dynamic>) builder) {
  final async = ref.watch(workerAccountProfileProvider);
  return async.when(
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(36), child: CircularProgressIndicator())),
      error: (error, _) => _EmptyCard(
          title: 'Could not load details', subtitle: error.toString()),
      data: (account) {
        final rawUser = account['user'];
        final user = rawUser is Map<String, dynamic>
            ? rawUser
            : const <String, dynamic>{};
        final rawProfile = user['workerProfile'];
        final profile = rawProfile is Map<String, dynamic>
            ? rawProfile
            : const <String, dynamic>{};
        return builder(
            {...profile, '_phoneVerified': user['phoneVerifiedAt'] != null});
      });
}

String _lastFour(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
}

String _maskAccount(String value) => '•••• ${_lastFour(value)}';

String _maskIfsc(String value) {
  if (value.length < 4) return '••••';
  return '••••${value.substring(value.length - 4)}';
}

String _maskUpi(String value) {
  if (value.contains('*') || value.contains('•')) return value;
  final separator = value.indexOf('@');
  if (separator <= 0 || separator == value.length - 1) return '••••';
  final handle = value.substring(0, separator);
  final visibleCount = handle.length >= 4 ? 2 : 1;
  return '${handle.substring(0, visibleCount)}••••${value.substring(separator)}';
}

List<Map<String, dynamic>> _availabilitySlots(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((slot) => Map<String, dynamic>.from(slot))
      .toList(growable: false);
}

String _availabilitySummary(List<Map<String, dynamic>> slots) {
  if (slots.isEmpty) return 'Not configured';
  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final days = slots
      .map((slot) => slot['dayOfWeek'])
      .whereType<num>()
      .map((day) => day.toInt())
      .where((day) => day >= 0 && day < dayNames.length)
      .toSet()
      .toList()
    ..sort();
  if (days.isEmpty) return 'Schedule configured';
  final daySummary = days.length == 7
      ? 'Every day'
      : days.map((day) => dayNames[day]).join(', ');
  final timeRanges = slots
      .map((slot) =>
          (slot['startTime']?.toString(), slot['endTime']?.toString()))
      .where((range) =>
          range.$1?.isNotEmpty == true && range.$2?.isNotEmpty == true)
      .map((range) => '${range.$1}–${range.$2}')
      .toSet();
  return timeRanges.isEmpty
      ? daySummary
      : '$daySummary · ${timeRanges.join(', ')}';
}

class _ProfileDetailScaffold extends StatelessWidget {
  const _ProfileDetailScaffold({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(title: Text(title), backgroundColor: _cream),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [child]));
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 12),
            ...children
          ])));
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.label,
      required this.value,
      required this.icon,
      this.action});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 6,
      leading: Icon(icon, color: _gold),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(value, style: const TextStyle(color: _muted)),
      trailing: action == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: action);
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(
      {required this.title, required this.icon, required this.color});
  final String title;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
      color: color.withValues(alpha: 0.12),
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: _ink)))
          ])));
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text, style: const TextStyle(color: _muted, fontSize: 12)));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.info_outline_rounded, color: _gold, size: 32),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted))
          ])));
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
              minimumSize: const Size.fromHeight(50)),
          child: Text(label)));
}

List<String> _skills(Map<String, dynamic> profile) {
  final raw = profile['skills'];
  if (raw is! List) return const [];
  return raw
      .map((item) {
        if (item is String) return item;
        if (item is Map<String, dynamic>) {
          final category = item['category'];
          final categoryName =
              category is Map<String, dynamic> ? category['name'] : null;
          return (item['name'] ??
                  item['categoryName'] ??
                  categoryName ??
                  'Service')
              .toString();
        }
        return 'Service';
      })
      .toSet()
      .toList();
}

String _text(dynamic value, String fallback) =>
    value == null || value.toString().trim().isEmpty
        ? fallback
        : value.toString();
