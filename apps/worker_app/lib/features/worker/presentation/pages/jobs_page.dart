import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/worker_job_providers.dart';
import 'generate_quote_page.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = ['incoming', 'accepted', 'active', 'completed'];

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Jobs',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review incoming requests, manage active jobs, and close completed work smoothly.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 18),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Incoming'),
                      Tab(text: 'Accepted'),
                      Tab(text: 'Active'),
                      Tab(text: 'Completed'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabs.map((tab) => _JobTabContent(tab: tab)).toList(),
              ),
            ),
          ],
        ),
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
      onRefresh: () async => ref.refresh(workerJobsProvider(tab).future),
      child: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                PremiumEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'No $tab jobs',
                  subtitle: 'You have no $tab jobs at the moment.',
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
        error: (e, s) => Center(child: Text('Error loading jobs: $e')),
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job, required this.tab});
  final WorkerJob job;
  final String tab;

  Future<void> _openNavigation(WorkerJob job) async {
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final query = [
      job.addressLabel?.trim(),
      job.cityName?.trim(),
      job.destinationQuery?.trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>().join(', ');
    if (query.isEmpty) {
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': 'Current+Location',
      'destination': query,
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to accept: $e')));
            }
          }
        }

        Future<void> declineJob() async {
          try {
            if (job.offerId == null) {
              throw Exception('Missing offer ID');
            }
            await ref
                .read(workerJobRepositoryProvider)
                .declineJob(job.offerId!);
            ref.invalidate(workerJobsProvider('incoming'));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Job declined')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to decline: $e')));
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
                            _openNavigation(job);
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
                                context.push('/chat?bookingId=${job.bookingId}');
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316).withValues(alpha: 0.15),
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
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Failed to accept: $e')));
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
                              throw Exception('Missing offer ID');
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
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Failed to decline: $e')));
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
                                builder: (_) => GenerateQuotePage(bookingId: job.bookingId),
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
                          context.push('/job-execution?bookingId=${job.bookingId}');
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
