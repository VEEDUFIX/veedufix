import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/worker_job_providers.dart';
import '../../data/worker_job_repository.dart';
import 'generate_quote_page.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final _tabs = ['incoming', 'accepted', 'active', 'completed'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabController == null) {
      final selectedTab = GoRouterState.of(context).uri.queryParameters['tab'];
      final initialIndex = switch (selectedTab) {
        'accepted' => 1,
        'active' => 2,
        'completed' => 3,
        _ => 0,
      };
      _tabController =
          TabController(length: 4, vsync: this, initialIndex: initialIndex);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incomingAsync = ref.watch(workerJobsProvider('incoming'));
    final acceptedAsync = ref.watch(workerJobsProvider('accepted'));
    final activeAsync = ref.watch(workerJobsProvider('active'));
    final completedAsync = ref.watch(workerJobsProvider('completed'));
    final acceptedBookingId = acceptedAsync.valueOrNull?.isNotEmpty == true
        ? acceptedAsync.valueOrNull!.first.bookingId
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appText(context, 'Jobs', 'வேலைகள்'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appText(
                        context,
                        'Review incoming requests, manage active jobs, and close completed work smoothly.',
                        'புதிய கோரிக்கைகளைப் பாருங்கள், செயலில் உள்ள வேலைகளை நிர்வகியுங்கள், முடிந்த வேலைகளை நிறைவு செய்யுங்கள்.'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 18),
                  _JobsOverviewCard(
                    incomingCount: incomingAsync.maybeWhen(
                      data: (jobs) => jobs.length,
                      orElse: () => null,
                    ),
                    acceptedCount: acceptedAsync.maybeWhen(
                      data: (jobs) => jobs.length,
                      orElse: () => null,
                    ),
                    activeCount: activeAsync.maybeWhen(
                      data: (jobs) => jobs.length,
                      orElse: () => null,
                    ),
                    completedCount: completedAsync.maybeWhen(
                      data: (jobs) => jobs.length,
                      orElse: () => null,
                    ),
                    onPrimaryAction: () => context.go('/jobs?tab=accepted'),
                    onSecondaryAction: acceptedBookingId == null
                        ? null
                        : () => context.push(
                              '/job-execution?bookingId=$acceptedBookingId',
                            ),
                  ),
                  const SizedBox(height: 18),
                  TabBar(
                    controller: _tabController!,
                    isScrollable: true,
                    tabs: [
                      Tab(text: appText(context, 'Incoming', 'புதியவை')),
                      Tab(text: appText(context, 'Accepted', 'ஏற்றவை')),
                      Tab(text: appText(context, 'Active', 'செயலில்')),
                      Tab(text: appText(context, 'Completed', 'முடிந்தவை')),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController!,
                children: _tabs.map((tab) => _JobTabContent(tab: tab)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsOverviewCard extends StatelessWidget {
  const _JobsOverviewCard({
    required this.incomingCount,
    required this.acceptedCount,
    required this.activeCount,
    required this.completedCount,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  final int? incomingCount;
  final int? acceptedCount;
  final int? activeCount;
  final int? completedCount;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.speed_rounded,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appText(context, 'Today at a glance', 'இன்றைய வேலைகள்'),
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appText(
                            context,
                            'Use the live counts to move faster between incoming leads, accepted work, and jobs already in motion.',
                            'புதிய கோரிக்கைகள், ஏற்றுக்கொண்ட வேலைகள் மற்றும் நடைபெறும் வேலைகளின் எண்ணிக்கையை இங்கே பார்க்கலாம்.'),
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _JobsStatPill(
                    label: appText(context, 'Incoming', 'புதியவை'),
                    value: _countLabel(incomingCount)),
                _JobsStatPill(
                    label: appText(context, 'Accepted', 'ஏற்றவை'),
                    value: _countLabel(acceptedCount)),
                _JobsStatPill(
                    label: appText(context, 'Active', 'செயலில்'),
                    value: _countLabel(activeCount)),
                _JobsStatPill(
                    label: appText(context, 'Completed', 'முடிந்தவை'),
                    value: _countLabel(completedCount)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onPrimaryAction,
                  icon:
                      const Icon(Icons.keyboard_arrow_right_rounded, size: 18),
                  label: Text(appText(context, 'Open accepted jobs',
                      'ஏற்றுக்கொண்ட வேலைகளைப் பாருங்கள்')),
                ),
                OutlinedButton.icon(
                  onPressed: onSecondaryAction,
                  icon: const Icon(Icons.request_quote_rounded, size: 18),
                  label: Text(appText(context, 'Start a quote',
                      'விலைமதிப்பீட்டைத் தொடங்குங்கள்')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _countLabel(int? count) {
    if (count == null) {
      return '...';
    }
    return '$count';
  }
}

class _JobsStatPill extends StatelessWidget {
  const _JobsStatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobTabContent extends ConsumerWidget {
  const _JobTabContent({required this.tab});
  final String tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(workerJobsProvider(tab));

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ref.refresh(workerJobsProvider(tab).future).then<void>((_) {});
        } catch (_) {}
      },
      child: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                PremiumEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: appText(context, 'No ${_jobTabLabel(tab)} jobs',
                      '${_jobTabTamil(tab)} வேலைகள் இல்லை'),
                  subtitle: appText(
                      context,
                      'You have no ${_jobTabLabel(tab)} jobs at the moment.',
                      'தற்போது ${_jobTabTamil(tab)} வேலைகள் எதுவும் இல்லை.'),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _JobCard(job: jobs[index], tab: tab);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appText(
                      context,
                      'Could not load jobs',
                      'வேலைகளை ஏற்ற முடியவில்லை',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appText(
                      context,
                      'Check your connection and try again.',
                      'இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(workerJobsProvider(tab)),
                    icon: const Icon(Icons.refresh_rounded),
                    label:
                        Text(appText(context, 'Try again', 'மீண்டும் முயற்சி')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job, required this.tab});
  final WorkerJob job;
  final String tab;

  Future<void> _openNavigation(BuildContext context, WorkerJob job) async {
    final lat = job.destinationLatitude;
    final lng = job.destinationLongitude;
    if (lat != null && lng != null) {
      final uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': 'Current+Location',
        'destination': '$lat,$lng',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      });
      await _launchDirections(context, uri);
      return;
    }

    final query = [
      job.addressLabel?.trim(),
      job.cityName?.trim(),
      job.destinationQuery?.trim(),
    ]
        .where((part) => part != null && part.isNotEmpty)
        .cast<String>()
        .join(', ');
    if (query.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'No destination is available for this job.',
                'இந்த வேலைக்கான இடம் கிடைக்கவில்லை.',
              ),
            ),
          ),
        );
      }
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': 'Current+Location',
      'destination': query,
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
    await _launchDirections(context, uri);
  }

  Future<void> _launchDirections(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'Could not open navigation.',
                'வழிசெலுத்தலைத் திறக்க முடியவில்லை.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'Could not open navigation.',
                'வழிசெலுத்தலைத் திறக்க முடியவில்லை.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showJobDetails(
      BuildContext context, WidgetRef ref, Color accent) {
    final formatCurrency = NumberFormat.simpleCurrency(
        locale: 'en_IN', name: 'INR', decimalDigits: 0);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final tt = Theme.of(sheetContext).textTheme;
        final cs = Theme.of(sheetContext).colorScheme;
        final isIncoming = tab == 'incoming';
        final canOpenExecution = tab == 'accepted' || tab == 'active';

        Future<void> acceptJob() async {
          try {
            await ref
                .read(workerJobRepositoryProvider)
                .acceptJob(job.bookingId);
            ref.invalidate(workerJobsProvider('incoming'));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Job accepted')));
            }
          } catch (error) {
            ref.invalidate(workerJobsProvider('incoming'));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_actionErrorMessage(context, error))));
            }
          }
        }

        Future<void> declineJob() async {
          try {
            if (job.offerId == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This offer is no longer available.'),
                  ),
                );
              }
              return;
            }
            await ref
                .read(workerJobRepositoryProvider)
                .declineJob(job.offerId!);
            ref.invalidate(workerJobsProvider('incoming'));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Job declined')));
            }
          } catch (error) {
            ref.invalidate(workerJobsProvider('incoming'));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_actionErrorMessage(context, error))));
            }
          }
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              top: 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AbzioTheme.buttonRadius),
                      ),
                      child: Icon(Icons.work_outline_rounded, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.customerName ?? 'Customer',
                              style: tt.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(job.serviceName,
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailLine(label: 'Booking', value: job.code),
                _DetailLine(
                    label: 'Scheduled',
                    value: DateFormat('MMM d, h:mm a').format(job.scheduledAt)),
                _DetailLine(
                    label: 'Amount',
                    value: formatCurrency.format(job.totalAmount)),
                if (job.addressLabel != null)
                  _DetailLine(label: 'Address', value: job.addressLabel!),
                const SizedBox(height: 16),
                if (isIncoming)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            acceptJob();
                          },
                          child: const Text('Accept Job'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            declineJob();
                          },
                          child: const Text('Decline'),
                        ),
                      ),
                    ],
                  )
                else if (canOpenExecution)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _openNavigation(context, job);
                          },
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text('Navigate'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                context.push(
                                  '/job-execution?bookingId=${job.bookingId}',
                                );
                              },
                              child: const Text('Open Execution'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                context
                                    .push('/chat?bookingId=${job.bookingId}');
                              },
                              child: const Text('Chat'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push('/chat?bookingId=${job.bookingId}');
                      },
                      child: const Text('Open chat'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _actionErrorMessage(BuildContext context, Object error) => error
          is WorkerJobActionError
      ? error.statusCode == 409 || error.statusCode == 410
          ? appText(
              context,
              'This job offer is no longer available. Refresh the list to see current jobs.',
              'இந்த வேலை வாய்ப்பு இனி கிடைக்காது. புதுப்பித்து தற்போதைய வேலைகளைப் பாருங்கள்.')
          : error.message
      : appText(context, 'Could not complete that action. Please try again.',
          'செயலை முடிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatCurrency = NumberFormat.simpleCurrency(
        locale: 'en_IN', name: 'INR', decimalDigits: 0);
    final accent = switch (tab) {
      'incoming' => const Color(0xFFC2A15E),
      'accepted' => const Color(0xFF38BDF8),
      'active' => const Color(0xFFF59E0B),
      'completed' => const Color(0xFF10B981),
      _ => colorScheme.primary,
    };

    return TapScale(
      onTap: () => _showJobDetails(context, ref, accent),
      child: PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      color: accent.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AbzioTheme.buttonRadius),
                    ),
                    child: Icon(Icons.person_rounded, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.customerName ?? 'Customer',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            if (job.customQuoteStatus == 'REQUESTED') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Quote Requested',
                                  style: TextStyle(
                                    color: Color(0xFFF97316),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _StatusChip(label: job.code, accent: accent),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          job.serviceName,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label:
                          DateFormat('MMM d, h:mm a').format(job.scheduledAt),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.payments_rounded,
                      label: formatCurrency.format(job.totalAmount),
                    ),
                  ),
                ],
              ),
              if (job.addressLabel != null) ...[
                const SizedBox(height: 10),
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: job.addressLabel!,
                ),
              ],
              const SizedBox(height: 14),
              if (tab == 'incoming')
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(workerJobRepositoryProvider)
                                .acceptJob(job.bookingId);
                            ref.invalidate(workerJobsProvider('incoming'));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Job accepted')));
                            }
                          } catch (error) {
                            ref.invalidate(workerJobsProvider('incoming'));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(_actionErrorMessage(context, error)),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            if (job.offerId == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'This offer is no longer available.'),
                                  ),
                                );
                              }
                              return;
                            }
                            await ref
                                .read(workerJobRepositoryProvider)
                                .declineJob(job.offerId!);
                            ref.invalidate(workerJobsProvider('incoming'));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Job declined')));
                            }
                          } catch (error) {
                            ref.invalidate(workerJobsProvider('incoming'));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(_actionErrorMessage(context, error)),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Decline'),
                      ),
                    ),
                  ],
                )
              else if (tab == 'accepted')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      context.push('/job-execution?bookingId=${job.bookingId}');
                    },
                    child: const Text('Start Job'),
                  ),
                )
              else if (tab == 'active')
                Column(
                  children: [
                    if (job.customQuoteStatus == 'REQUESTED') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    GenerateQuotePage(bookingId: job.bookingId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.request_quote_rounded),
                          label: const Text('Generate Quote'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          context.push(
                              '/job-execution?bookingId=${job.bookingId}');
                        },
                        child: const Text('Continue Job'),
                      ),
                    ),
                  ],
                )
              else if (tab == 'completed')
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'Completed',
                      style:
                          TextStyle(color: accent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _jobTabLabel(String tab) => switch (tab) {
      'incoming' => 'incoming',
      'accepted' => 'accepted',
      'active' => 'active',
      'completed' => 'completed',
      _ => tab,
    };

String _jobTabTamil(String tab) => switch (tab) {
      'incoming' => 'புதிய',
      'accepted' => 'ஏற்றுக்கொண்ட',
      'active' => 'செயலில் உள்ள',
      'completed' => 'முடிந்த',
      _ => tab,
    };

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
          Expanded(
              child: Text(value,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
