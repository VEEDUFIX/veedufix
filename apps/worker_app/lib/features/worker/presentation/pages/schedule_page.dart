import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:intl/intl.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late DateTime _currentWeekStart;
  late int _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 1 = Monday, 7 = Sunday
    final weekday = now.weekday; 
    _currentWeekStart = now.subtract(Duration(days: weekday - 1));
    _selectedDayIndex = weekday - 1;
  }

  Future<void> _onRefresh() async {
    ref.invalidate(workerJobsProvider('accepted'));
    ref.invalidate(workerJobsProvider('active'));
    // Wait for the new values to load
    await Future.wait([
      ref.read(workerJobsProvider('accepted').future),
      ref.read(workerJobsProvider('active').future),
    ]).catchError((_) => <List<WorkerJob>>[]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final acceptedJobsAsync = ref.watch(workerJobsProvider('accepted'));
    final activeJobsAsync = ref.watch(workerJobsProvider('active'));

    final daysList = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'My Schedule',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/availability'),
            icon: Icon(Icons.add_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Column(
          children: [
            // Weekly Calendar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final isSelected = _selectedDayIndex == index;
                  final date = _currentWeekStart.add(Duration(days: index));
                  
                  return TapScale(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            daysList[index],
                            style: tt.labelSmall?.copyWith(
                              color: isSelected ? cs.onPrimary.withValues(alpha: 0.8) : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date.day.toString(),
                            style: tt.titleMedium?.copyWith(
                              color: isSelected ? cs.onPrimary : cs.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // Timeline / Data
            Expanded(
              child: Builder(
                builder: (context) {
                  if (acceptedJobsAsync.isLoading || activeJobsAsync.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (acceptedJobsAsync.hasError || activeJobsAsync.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load jobs',
                            style: tt.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _onRefresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final acceptedJobs = acceptedJobsAsync.valueOrNull ?? [];
                  final activeJobs = activeJobsAsync.valueOrNull ?? [];
                  final allJobs = [...acceptedJobs, ...activeJobs];

                  final selectedDate = _currentWeekStart.add(Duration(days: _selectedDayIndex));
                  
                  final filteredJobs = allJobs.where((job) {
                    return job.scheduledAt.year == selectedDate.year &&
                           job.scheduledAt.month == selectedDate.month &&
                           job.scheduledAt.day == selectedDate.day;
                  }).toList();

                  // Sort by time
                  filteredJobs.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

                  if (filteredJobs.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                      children: const [
                        PremiumEmptyState(
                          icon: Icons.event_available_rounded,
                          title: 'No jobs today',
                          subtitle: 'Jobs scheduled on this day will appear here.',
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: filteredJobs.length,
                    itemBuilder: (context, index) {
                      final job = filteredJobs[index];
                      final isLast = index == filteredJobs.length - 1;
                      final isActive = job.status.toLowerCase() == 'active';
                      final accent = isActive ? const Color(0xFF10B981) : cs.primary;
                      
                      final timeStr = DateFormat('hh:mm a').format(job.scheduledAt);

                      return IntrinsicHeight(
                        child: Row(
                          children: [
                            // Time
                            SizedBox(
                              width: 64,
                              child: Text(
                                timeStr.replaceAll(' ', '\n'),
                                textAlign: TextAlign.right,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Divider line
                            Column(
                              children: [
                                Container(
                                  height: 16,
                                  width: 16,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: accent, width: 3),
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      color: cs.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Card
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              job.serviceName,
                                              style: tt.titleMedium?.copyWith(
                                                color: cs.onSurface,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: accent.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              // Assuming 1h duration as default or derived if available
                                              '?',
                                              style: tt.labelSmall?.copyWith(
                                                color: accent,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 14,
                                            color: cs.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              job.addressLabel ?? 'No address provided',
                                              style: tt.bodySmall?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
          ],
        ),
      ),
    );
  }
}

