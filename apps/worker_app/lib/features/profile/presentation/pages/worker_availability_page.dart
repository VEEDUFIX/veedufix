import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/worker_availability_api.dart';

class WorkerAvailabilityPage extends ConsumerStatefulWidget {
  const WorkerAvailabilityPage({super.key});

  @override
  ConsumerState<WorkerAvailabilityPage> createState() => _WorkerAvailabilityPageState();
}

class _WorkerAvailabilityPageState extends ConsumerState<WorkerAvailabilityPage> {
  late final WorkerAvailabilityApi _api;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  final Map<int, List<_AvailabilitySlotDraft>> _slotsByDay = <int, List<_AvailabilitySlotDraft>>{};

  @override
  void initState() {
    super.initState();
    _api = WorkerAvailabilityApi(ref.read(apiClientProvider).dio);
    for (var day = 0; day < 7; day++) {
      _slotsByDay[day] = <_AvailabilitySlotDraft>[];
    }
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final slots = await _api.getAvailability();
      if (!mounted) {
        return;
      }
      for (final entry in _slotsByDay.entries) {
        entry.value.clear();
      }
      for (final slot in slots) {
        _slotsByDay[slot.dayOfWeek]?.add(_AvailabilitySlotDraft.fromApi(slot));
      }
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error is DioException ? _errorMessageFromDio(error) : error.toString();
      });
    }
  }

  Future<void> _saveAvailability() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final slots = <WeeklyAvailabilitySlot>[];
      for (final day in _slotsByDay.keys.toList()..sort()) {
        for (final slot in _slotsByDay[day] ?? const <_AvailabilitySlotDraft>[]) {
          if (slot.startTime == null || slot.endTime == null) {
            continue;
          }
          slots.add(WeeklyAvailabilitySlot(
            dayOfWeek: day,
            startTime: _formatTime(slot.startTime!),
            endTime: _formatTime(slot.endTime!),
          ));
        }
      }
      await _api.setAvailability(slots);
      await _loadAvailability();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save availability: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) => index);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly availability'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveAvailability,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAvailability,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set your weekly schedule',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Customers will only see you during the windows you publish here.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(_errorMessage!),
                ),
              )
            else
              ...days.map(
                (day) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DayScheduleCard(
                    dayOfWeek: day,
                    slots: _slotsByDay[day] ?? const <_AvailabilitySlotDraft>[],
                    onAddSlot: () => setState(() {
                      _slotsByDay[day]!.add(const _AvailabilitySlotDraft());
                    }),
                    onRemoveSlot: (index) => setState(() {
                      _slotsByDay[day]!.removeAt(index);
                    }),
                    onUpdateSlot: (index, next) => setState(() {
                      _slotsByDay[day]![index] = next;
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayScheduleCard extends StatelessWidget {
  const _DayScheduleCard({
    required this.dayOfWeek,
    required this.slots,
    required this.onAddSlot,
    required this.onRemoveSlot,
    required this.onUpdateSlot,
  });

  final int dayOfWeek;
  final List<_AvailabilitySlotDraft> slots;
  final VoidCallback onAddSlot;
  final void Function(int index) onRemoveSlot;
  final void Function(int index, _AvailabilitySlotDraft next) onUpdateSlot;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dayLabel(dayOfWeek),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddSlot,
                  icon: const Icon(Icons.add),
                  label: const Text('Add slot'),
                ),
              ],
            ),
            if (slots.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No availability set for this day.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              ...slots.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _TimeSlotEditor(
                    label: 'Slot ${entry.key + 1}',
                    slot: entry.value,
                    onChanged: (next) => onUpdateSlot(entry.key, next),
                    onDelete: () => onRemoveSlot(entry.key),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlotEditor extends StatelessWidget {
  const _TimeSlotEditor({
    required this.label,
    required this.slot,
    required this.onChanged,
    required this.onDelete,
  });

  final String label;
  final _AvailabilitySlotDraft slot;
  final ValueChanged<_AvailabilitySlotDraft> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Start',
                  value: slot.startTime == null ? 'Select' : _formatTime(slot.startTime!),
                  onPressed: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: slot.startTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (selected != null) {
                      onChanged(slot.copyWith(startTime: selected));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeButton(
                  label: 'End',
                  value: slot.endTime == null ? 'Select' : _formatTime(slot.endTime!),
                  onPressed: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: slot.endTime ?? const TimeOfDay(hour: 18, minute: 0),
                    );
                    if (selected != null) {
                      onChanged(slot.copyWith(endTime: selected));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _AvailabilitySlotDraft {
  const _AvailabilitySlotDraft({
    this.startTime,
    this.endTime,
  });

  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  factory _AvailabilitySlotDraft.fromApi(WeeklyAvailabilitySlot slot) {
    return _AvailabilitySlotDraft(
      startTime: _parseTime(slot.startTime),
      endTime: _parseTime(slot.endTime),
    );
  }

  _AvailabilitySlotDraft copyWith({
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return _AvailabilitySlotDraft(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

String _dayLabel(int dayOfWeek) {
  switch (dayOfWeek) {
    case 0:
      return 'Sunday';
    case 1:
      return 'Monday';
    case 2:
      return 'Tuesday';
    case 3:
      return 'Wednesday';
    case 4:
      return 'Thursday';
    case 5:
      return 'Friday';
    case 6:
      return 'Saturday';
    default:
      return 'Day $dayOfWeek';
  }
}

String _formatTime(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return TimeOfDay(hour: hour, minute: minute);
}

String _errorMessageFromDio(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
  }
  return error.message ?? 'Request failed';
}
