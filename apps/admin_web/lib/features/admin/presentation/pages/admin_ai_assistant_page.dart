import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

enum _AssistantMode {
  catalogDraft,
  catalogQuality,
  catalogSearch,
  insights,
  support
}

class AdminAiAssistantPage extends ConsumerStatefulWidget {
  const AdminAiAssistantPage({super.key});

  @override
  ConsumerState<AdminAiAssistantPage> createState() =>
      _AdminAiAssistantPageState();
}

class _AdminAiAssistantPageState extends ConsumerState<AdminAiAssistantPage> {
  late final Dio _dio;
  final _promptController = TextEditingController();
  final _ticketController = TextEditingController();
  final _conversation = <({String role, String text})>[];
  final _draftControllers = <String, TextEditingController>{};
  final _selectedDraftFields = <String>{};
  _AssistantMode _mode = _AssistantMode.catalogDraft;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _subcategories = const [];
  String? _categoryId;
  String? _subcategoryId;
  String _supportTask = 'summarize';
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _dio = ref.read(apiClientProvider).dio;
    _loadStatus();
    _loadCatalogOptions();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _ticketController.dispose();
    for (final controller in _draftControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final response = await _dio.get<dynamic>('/admin/ai/status');
      if (mounted) setState(() => _status = _map(response.data));
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _loadCatalogOptions() async {
    try {
      final response = await _dio.get<dynamic>('/admin/ai/catalog-options');
      final data = _map(response.data);
      if (!mounted) return;
      setState(() {
        _categories = _maps(data['categories']);
        _subcategories = _maps(data['subcategories']);
      });
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  List<Map<String, dynamic>> get _availableSubcategories => _subcategories
      .where((item) => _categoryId == null || item['categoryId'] == _categoryId)
      .toList(growable: false);

  Future<void> _run() async {
    if (_loading) return;
    final prompt = _promptController.text.trim();
    if (_mode != _AssistantMode.catalogQuality &&
        _mode != _AssistantMode.insights &&
        prompt.isEmpty) {
      setState(() => _error = _mode == _AssistantMode.support
          ? 'Enter a support ticket ID first.'
          : 'Enter a prompt first.');
      return;
    }
    if (_mode == _AssistantMode.support &&
        _ticketController.text.trim().isEmpty) {
      setState(() => _error = 'Enter the support ticket ID to summarize.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _conversation.add((role: 'You', text: _promptForMode(prompt)));
      _result = null;
    });
    try {
      late final Response<dynamic> response;
      switch (_mode) {
        case _AssistantMode.catalogDraft:
          response = await _dio.post<dynamic>('/admin/ai/catalog-draft', data: {
            'serviceName': prompt,
            if (_categoryId != null) 'categoryId': _categoryId,
            if (_subcategoryId != null) 'subcategoryId': _subcategoryId,
          });
          break;
        case _AssistantMode.catalogQuality:
          response = await _dio.get<dynamic>('/admin/ai/catalog-quality');
          break;
        case _AssistantMode.catalogSearch:
          response = await _dio
              .post<dynamic>('/admin/ai/search', data: {'prompt': prompt});
          break;
        case _AssistantMode.insights:
          response = await _dio
              .post<dynamic>('/admin/ai/insights', data: {'days': 30});
          break;
        case _AssistantMode.support:
          response =
              await _dio.post<dynamic>('/admin/ai/support-assistant', data: {
            'ticketId': _ticketController.text.trim(),
            'task': _supportTask,
            if (prompt.isNotEmpty) 'additionalInstruction': prompt,
          });
          break;
      }
      if (!mounted) return;
      final result = _map(response.data);
      setState(() {
        _result = result;
        _conversation.add((role: 'Assistant', text: _resultSummary(result)));
        if (_mode == _AssistantMode.catalogDraft) _prepareDraft(result);
      });
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'The request could not be completed. Retry or continue with the existing Admin tools.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _promptForMode(String prompt) => switch (_mode) {
        _AssistantMode.catalogDraft => 'Generate catalog draft: $prompt',
        _AssistantMode.catalogQuality => 'Review catalog quality',
        _AssistantMode.catalogSearch => 'Search catalog: $prompt',
        _AssistantMode.insights =>
          'Summarize the last 30 days of business data',
        _AssistantMode.support =>
          'Support ${_supportTask.replaceAll('_', ' ')} for ${_ticketController.text.trim()}',
      };

  String _resultSummary(Map<String, dynamic> result) => switch (_mode) {
        _AssistantMode.catalogDraft =>
          'Generated an editable, unverified service draft.',
        _AssistantMode.catalogQuality =>
          '${_maps(result['findings']).length} catalog findings returned from ${result['recordsAnalyzed'] ?? 0} records.',
        _AssistantMode.catalogSearch => result['needsClarification'] == true
            ? result['clarification']?.toString() ??
                'Please clarify the search.'
            : '${result['count'] ?? 0} matching catalog records.',
        _AssistantMode.insights =>
          'Verified metrics for the selected reporting period are ready.',
        _AssistantMode.support =>
          'Generated a draft using the selected support ticket. Review it before use.',
      };

  void _prepareDraft(Map<String, dynamic> result) {
    for (final controller in _draftControllers.values) {
      controller.dispose();
    }
    _draftControllers.clear();
    _selectedDraftFields.clear();
    final draft = _map(result['draft']);
    for (final key in const [
      'serviceName',
      'shortDescription',
      'description',
      'inclusions',
      'exclusions',
      'requiredSkills',
      'requiredTools',
      'requiredDocuments',
      'requirements',
      'searchAliases',
      'seoTitle',
      'seoDescription',
      'seoKeywords',
    ]) {
      final value = draft[key];
      final text = value is List
          ? value.map((item) => item.toString()).join('\n')
          : value?.toString() ?? '';
      _draftControllers[key] = TextEditingController(text: text);
      _selectedDraftFields.add(key);
    }
    final duration = draft['suggestedEstimatedDurationMins'];
    if (duration != null) {
      _draftControllers['estimatedDurationMins'] =
          TextEditingController(text: duration.toString());
      _selectedDraftFields.add('estimatedDurationMins');
    }
  }

  Future<void> _openDraftInCatalog() async {
    final result = _result;
    if (result == null || _draftControllers.isEmpty) return;
    final draft = <String, dynamic>{
      'categoryId': result['categoryId'],
      'subcategoryId': result['subcategoryId'],
      'aiGeneratedDraft': true,
    };
    for (final field in _selectedDraftFields) {
      final value = _draftControllers[field]?.text.trim() ?? '';
      if (field == 'estimatedDurationMins') {
        final duration = int.tryParse(value);
        if (duration != null && duration > 0) draft[field] = duration;
      } else if (const {
        'inclusions',
        'exclusions',
        'requiredSkills',
        'requiredTools',
        'requiredDocuments',
        'requirements'
      }.contains(field)) {
        draft[field] = value
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
      } else if (value.isNotEmpty) {
        draft[field] = value;
      }
    }
    await context.push('/catalog', extra: {'aiDraft': draft});
  }

  void _setMode(_AssistantMode value) {
    setState(() {
      _mode = value;
      _error = null;
      _promptController.clear();
    });
  }

  String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.response?.statusCode == 503) {
      return 'AI generation is not configured. Ask the backend administrator to set GEMINI_API_KEY.';
    }
    return 'Could not reach the Admin AI service. Retry, or continue with the existing Admin workflow.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = _status?['configured'] == true;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('AI Assistant', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                    'Use verified catalog and business data; review every generated suggestion before applying it.',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 18),
                if (_status != null)
                  Card(
                    child: ListTile(
                      leading: Icon(
                          configured ? Icons.auto_awesome : Icons.info_outline),
                      title: Text(configured
                          ? 'AI generation is configured'
                          : 'AI generation needs configuration'),
                      subtitle: Text(_status?['message']?.toString() ?? ''),
                      trailing: Text(_status?['provider']?.toString() ?? ''),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _modeChip(_AssistantMode.catalogDraft, 'Service draft',
                        Icons.add_box_outlined),
                    _modeChip(_AssistantMode.catalogQuality, 'Catalog quality',
                        Icons.fact_check_outlined),
                    _modeChip(_AssistantMode.catalogSearch,
                        'Find catalog records', Icons.search),
                    _modeChip(_AssistantMode.insights, 'Business insights',
                        Icons.insights_outlined),
                    _modeChip(_AssistantMode.support, 'Support assistant',
                        Icons.support_agent_outlined),
                  ],
                ),
                const SizedBox(height: 16),
                _buildModeControls(theme),
                const SizedBox(height: 12),
                if (_conversation.isNotEmpty) _buildConversation(theme),
                if (_loading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text(
                      'Checking authorized data and preparing the response…'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(_error!),
                      trailing: IconButton(
                          tooltip: 'Retry',
                          onPressed: _loading ? null : _run,
                          icon: const Icon(Icons.refresh)),
                    ),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  _buildResult(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip(_AssistantMode mode, String label, IconData icon) =>
      ChoiceChip(
        selected: _mode == mode,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onSelected: (_) => _setMode(mode),
      );

  Widget _buildModeControls(ThemeData theme) {
    final enabled = !_loading &&
        (_mode == _AssistantMode.catalogQuality ||
            _mode == _AssistantMode.insights ||
            _status?['configured'] == true ||
            _mode == _AssistantMode.catalogSearch);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_mode == _AssistantMode.catalogDraft) ...[
              Text('Suggested actions', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                  'Generate a service description, inclusions, requirements, aliases, SEO text, and a duration estimate for review.'),
              const SizedBox(height: 12),
              _categorySelector(),
              const SizedBox(height: 12),
            ],
            if (_mode == _AssistantMode.support) ...[
              TextField(
                  controller: _ticketController,
                  decoration:
                      const InputDecoration(labelText: 'Support ticket ID')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _supportTask,
                decoration: const InputDecoration(labelText: 'Task'),
                items: const [
                  DropdownMenuItem(
                      value: 'summarize', child: Text('Summarize ticket')),
                  DropdownMenuItem(
                      value: 'categorize', child: Text('Categorize complaint')),
                  DropdownMenuItem(
                      value: 'draft_response', child: Text('Draft a response')),
                ],
                onChanged: (value) =>
                    setState(() => _supportTask = value ?? 'summarize'),
              ),
              const SizedBox(height: 8),
            ],
            if (_mode == _AssistantMode.catalogQuality)
              const Text(
                  'Find missing images, weak descriptions, missing aliases, incomplete setup, taxonomy mismatches, and possible duplicate names.'),
            if (_mode == _AssistantMode.insights)
              const Text(
                  'Read-only summary of booking status, booked value, captured payments, service and locality demand, active verified Partner count, and support ticket counts for the last 30 days.'),
            if (_mode != _AssistantMode.catalogQuality &&
                _mode != _AssistantMode.insights) ...[
              TextField(
                controller: _promptController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: switch (_mode) {
                    _AssistantMode.catalogDraft =>
                      'Service name and optional context',
                    _AssistantMode.catalogSearch =>
                      'Ask a safe catalog question',
                    _AssistantMode.support =>
                      'Optional instruction for the draft',
                    _ => 'Ask the Admin assistant',
                  },
                  hintText: switch (_mode) {
                    _AssistantMode.catalogDraft =>
                      'e.g. Split AC deep cleaning',
                    _AssistantMode.catalogSearch =>
                      'e.g. Show inactive AC services',
                    _AssistantMode.support =>
                      'e.g. Keep the reply concise; do not promise a refund',
                    _ => null,
                  },
                ),
                onSubmitted: (_) => _run(),
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_mode == _AssistantMode.catalogSearch) ...[
                  _examplePrompt('Show inactive AC services'),
                  _examplePrompt('Find services without images'),
                  _examplePrompt(
                      'Show published services with booking disabled'),
                  _examplePrompt('Find services with incomplete descriptions'),
                ],
                if (_mode == _AssistantMode.catalogDraft)
                  _examplePrompt('Generate a draft for kitchen chimney repair'),
                FilledButton.icon(
                  onPressed: enabled ? _run : null,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(_loading ? 'Working…' : 'Run assistant'),
                ),
                if (_conversation.isNotEmpty)
                  TextButton.icon(
                      onPressed: _clearSession,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear session')),
              ],
            ),
            if (!_statusReadyForMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Generated suggestions require a configured backend provider. Search and deterministic checks remain available.',
                    style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  bool get _statusReadyForMode =>
      _mode == _AssistantMode.catalogQuality ||
      _mode == _AssistantMode.catalogSearch ||
      _mode == _AssistantMode.insights ||
      _status?['configured'] == true;

  Widget _categorySelector() => Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration:
                  const InputDecoration(labelText: 'Category (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Let AI suggest from active categories')),
                ..._categories.map((item) => DropdownMenuItem(
                    value: item['id']?.toString(),
                    child: Text(item['name']?.toString() ?? 'Category')))
              ],
              onChanged: (value) => setState(() {
                _categoryId = value;
                if (!_availableSubcategories
                    .any((item) => item['id'] == _subcategoryId)) {
                  _subcategoryId = null;
                }
              }),
            ),
          ),
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String?>(
              initialValue: _subcategoryId,
              decoration:
                  const InputDecoration(labelText: 'Subcategory (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('No subcategory selected')),
                ..._availableSubcategories.map((item) => DropdownMenuItem(
                    value: item['id']?.toString(),
                    child: Text(item['name']?.toString() ?? 'Subcategory')))
              ],
              onChanged: (value) => setState(() => _subcategoryId = value),
            ),
          ),
        ],
      );

  Widget _examplePrompt(String value) => ActionChip(
        label: Text(value),
        onPressed: () => setState(() => _promptController.text = value),
      );

  Widget _buildConversation(ThemeData theme) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This session', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final entry in _conversation.take(20))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 88,
                          child: Text(entry.role,
                              style: theme.textTheme.labelLarge)),
                      Expanded(child: Text(entry.text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildResult(ThemeData theme) => switch (_mode) {
        _AssistantMode.catalogDraft => _buildDraft(theme),
        _AssistantMode.catalogQuality => _buildQuality(theme),
        _AssistantMode.catalogSearch => _buildSearch(theme),
        _AssistantMode.insights => _buildInsights(theme),
        _AssistantMode.support => _buildSupport(theme),
      };

  Widget _buildDraft(ThemeData theme) {
    final draft = _map(_result?['draft']);
    final notes = _strings(draft['reviewNotes']);
    final optionSuggestions = [
      ..._maps(draft['suggestedVariants'])
          .map((item) => 'Option: ${item['name']} — ${item['description']}'),
      ..._maps(draft['suggestedAddons'])
          .map((item) => 'Add-on: ${item['name']} — ${item['description']}'),
    ];
    const labels = {
      'serviceName': 'Service name',
      'shortDescription': 'Short description',
      'description': 'Description',
      'inclusions': 'Inclusions',
      'exclusions': 'Exclusions',
      'requiredSkills': 'Required skills',
      'requiredTools': 'Required tools',
      'requiredDocuments': 'Required documents',
      'requirements': 'Before-booking requirements',
      'searchAliases': 'Search aliases',
      'seoTitle': 'SEO title',
      'seoDescription': 'SEO description',
      'seoKeywords': 'SEO keywords',
      'estimatedDurationMins':
          'Estimated duration in minutes (AI suggestion; verify)',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generated draft · unverified',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
                'Prices, tax, SAC, warranty, policy, activation, and publication were not generated. Verify each field before saving.'),
            const SizedBox(height: 12),
            for (final entry in _draftControllers.entries)
              CheckboxListTile(
                value: _selectedDraftFields.contains(entry.key),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(labels[entry.key] ?? entry.key),
                subtitle: TextField(
                  controller: entry.value,
                  minLines:
                      entry.key == 'description' || entry.key.endsWith('s')
                          ? 2
                          : 1,
                  maxLines: entry.key == 'description'
                      ? 5
                      : entry.key.endsWith('s')
                          ? 4
                          : 2,
                  decoration: const InputDecoration(isDense: true),
                ),
                onChanged: (selected) => setState(() {
                  if (selected == true) {
                    _selectedDraftFields.add(entry.key);
                  } else {
                    _selectedDraftFields.remove(entry.key);
                  }
                }),
              ),
            if (_result?['categoryId'] != null)
              Text(
                  'Matched category ID: ${_result!['categoryId']} · subcategory: ${_result?['subcategoryId'] ?? 'choose in catalog'}'),
            if (draft['durationRationale'] != null)
              Text('Duration review note: ${draft['durationRationale']}'),
            if (optionSuggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Option ideas (no prices generated)',
                  style: theme.textTheme.titleSmall),
              for (final suggestion in optionSuggestions) Text('• $suggestion'),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Review notes', style: theme.textTheme.titleSmall),
              for (final note in notes) Text('• $note'),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                  onPressed:
                      _selectedDraftFields.isEmpty ? null : _openDraftInCatalog,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Review in catalog form')),
              TextButton(
                  onPressed: _discardDraft, child: const Text('Discard draft')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildQuality(ThemeData theme) {
    final findings = _maps(_result?['findings']);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Catalog quality findings',
                  style: theme.textTheme.titleLarge),
              Text(
                  '${_result?['recordsAnalyzed'] ?? 0} records inspected · semantic review: ${_result?['semanticAnalysis'] ?? 'not available'}'),
              if (_result?['truncated'] == true)
                const Text(
                    'The catalog exceeded the review limit; this result covers the latest 500 records.'),
              if (findings.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No objective catalog gaps were found in the inspected records.')),
              for (final finding in findings) _findingTile(finding, theme),
            ])));
  }

  Widget _findingTile(Map<String, dynamic> item, ThemeData theme) => ListTile(
        title: Text(
            '${item['serviceName'] ?? 'Service'} · ${item['problem'] ?? ''}'),
        subtitle: Text(
            '${item['whyItMatters'] ?? ''}\nSuggested: ${item['suggestedFix'] ?? ''}\nReview status: ${item['reviewStatus'] ?? 'review'}'),
        isThreeLine: true,
        trailing: IconButton(
            tooltip: 'Open service in catalog',
            onPressed: item['serviceId'] == null
                ? null
                : () => context.go('/catalog/services/${item['serviceId']}'),
            icon: const Icon(Icons.open_in_new)),
      );

  Widget _buildSearch(ThemeData theme) {
    final data = _result ?? const <String, dynamic>{};
    final services = _maps(data['services']);
    final filters = _map(data['filtersApplied']);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  data['needsClarification'] == true
                      ? 'Clarification needed'
                      : '${data['count'] ?? 0} matches',
                  style: theme.textTheme.titleLarge),
              if (data['needsClarification'] == true)
                Text(data['clarification']?.toString() ?? ''),
              if (filters.isNotEmpty)
                Text(
                    'Filters applied: ${filters.entries.map((e) => '${e.key}=${e.value}').join(' · ')}'),
              if (data['truncated'] == true)
                const Text('Results were limited to the first 50 matches.'),
              for (final item in services)
                ListTile(
                  title: Text(item['name']?.toString() ?? 'Service'),
                  subtitle: Text(
                      '${_map(item['category'])['name'] ?? ''} · ${_map(item['subcategory'])['name'] ?? ''} · ${item['publicationStatus'] ?? ''} · ${item['isActive'] == true ? 'Active' : 'Inactive'}'),
                  trailing: IconButton(
                      tooltip: 'Open catalog service',
                      onPressed: () =>
                          context.go(item['href']?.toString() ?? '/catalog'),
                      icon: const Icon(Icons.open_in_new)),
                ),
            ])));
  }

  Widget _buildInsights(ThemeData theme) {
    final summary = _map(_result?['summary']);
    final totals = _map(summary['totals']);
    final metrics = [
      ('Bookings', totals['bookings']),
      ('Cancelled', totals['cancelledBookings']),
      ('Completed', totals['completedBookings']),
      ('Booked value', '₹${totals['bookedValue'] ?? 0}'),
      ('Captured payments', '₹${totals['capturedPayments'] ?? 0}'),
      ('Active verified Partners', totals['activeVerifiedPartners']),
      ('Support tickets', totals['supportTickets']),
    ];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  'Verified business metrics · last ${_map(summary['period'])['days'] ?? 30} days',
                  style: theme.textTheme.titleLarge),
              Text(_map(summary['definitions'])['bookedValue']?.toString() ??
                  ''),
              if (_result?['narrativeStatus'] == 'available' &&
                  _result?['narrative'] is Map) ...[
                const SizedBox(height: 10),
                Text('AI analysis · based on verified metrics',
                    style: theme.textTheme.titleSmall),
                Text(_map(_result?['narrative'])['summary']?.toString() ?? ''),
                for (final point
                    in _strings(_map(_result?['narrative'])['observations']))
                  Text('• $point'),
                for (final idea
                    in _strings(_map(_result?['narrative'])['recommendations']))
                  Text('Recommendation to review: $idea'),
                for (final limit
                    in _strings(_map(_result?['narrative'])['limitations']))
                  Text('Limitation: $limit'),
              ] else if (_result?['narrativeStatus'] == 'unavailable')
                const Text(
                    'AI narrative is temporarily unavailable; verified metrics remain available.'),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final item in metrics)
                  Chip(label: Text('${item.$1}: ${item.$2 ?? 0}'))
              ]),
              const SizedBox(height: 12),
              Text('Popular services', style: theme.textTheme.titleSmall),
              for (final item in _maps(summary['popularServices']))
                Text('${item['name']}: ${item['bookings']} bookings'),
              Text('Localities', style: theme.textTheme.titleSmall),
              for (final item in _maps(summary['localities']))
                Text('${item['city']}: ${item['bookings']} bookings'),
              for (final limitation in _strings(summary['limitations']))
                Text('Data limitation: $limitation'),
            ])));
  }

  Widget _buildSupport(ThemeData theme) {
    final draft = _map(_map(_result?['draft']));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Support draft · review before use',
                  style: theme.textTheme.titleLarge),
              Text('Category suggestion: ${draft['category'] ?? 'OTHER'}'),
              const SizedBox(height: 8),
              Text('Summary', style: theme.textTheme.titleSmall),
              Text(draft['summary']?.toString() ?? ''),
              if ((draft['suggestedResponse']?.toString() ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Draft response (not sent)',
                    style: theme.textTheme.titleSmall),
                SelectableText(draft['suggestedResponse'].toString()),
              ],
              for (final step in _strings(draft['nextSteps']))
                Text('Next step: $step'),
              for (final caution in _strings(draft['reviewCautions']))
                Text('Review caution: $caution'),
            ])));
  }

  void _clearSession() => setState(() {
        _conversation.clear();
        _result = null;
        _error = null;
        _promptController.clear();
      });

  void _discardDraft() {
    for (final controller in _draftControllers.values) {
      controller.dispose();
    }
    setState(() {
      _draftControllers.clear();
      _selectedDraftFields.clear();
      _result = null;
    });
  }
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((item) => _map(item)).toList(growable: false)
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const [];
