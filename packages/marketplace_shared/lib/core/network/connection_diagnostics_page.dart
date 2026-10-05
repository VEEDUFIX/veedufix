import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import 'connectivity_provider.dart';

class ConnectionDiagnosticsPage extends ConsumerStatefulWidget {
  const ConnectionDiagnosticsPage({super.key});

  @override
  ConsumerState<ConnectionDiagnosticsPage> createState() =>
      _ConnectionDiagnosticsPageState();
}

class _ConnectionDiagnosticsPageState
    extends ConsumerState<ConnectionDiagnosticsPage> {
  bool _checking = false;
  bool? _apiReachable;
  bool? _serviceHealthy;
  DateTime? _checkedAt;
  Duration? _responseTime;

  Future<void> _checkConnection() async {
    if (_checking) return;
    setState(() => _checking = true);
    final startedAt = DateTime.now();

    try {
      final response = await ref.read(apiClientProvider).dio.get<dynamic>(
        '/health',
        options: Options(
          extra: const {'skipAuth': true},
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final payload = response.data;
      final healthy = response.statusCode == 200 &&
          payload is Map &&
          payload['ok'] == true;
      if (!mounted) return;
      setState(() {
        _apiReachable = true;
        _serviceHealthy = healthy;
        _responseTime = DateTime.now().difference(startedAt);
        _checkedAt = DateTime.now();
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _apiReachable = error.response != null;
        _serviceHealthy = false;
        _responseTime = DateTime.now().difference(startedAt);
        _checkedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiReachable = false;
        _serviceHealthy = false;
        _responseTime = DateTime.now().difference(startedAt);
        _checkedAt = DateTime.now();
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _copyReport(bool? hasNetwork) async {
    final apiHost = Uri.tryParse(
          ref.read(apiClientProvider).dio.options.baseUrl,
        )?.host ??
        'unknown';
    final network = hasNetwork == null
        ? 'Unknown'
        : hasNetwork
            ? 'Available'
            : 'Unavailable';
    final api = _apiReachable == null
        ? 'Not checked'
        : _apiReachable!
            ? (_serviceHealthy == true ? 'Healthy' : 'Degraded')
            : 'Unreachable';
    final checked = _checkedAt?.toIso8601String() ?? 'Not checked';
    final latency = _responseTime == null
        ? 'Not available'
        : '${_responseTime!.inMilliseconds} ms';
    final report = [
      'Veedufix connection diagnostics',
      'Network: $network',
      'API: $api',
      'API host: $apiHost',
      'Response time: $latency',
      'Platform: ${defaultTargetPlatform.name}',
      'Checked: $checked',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics copied. No account details included.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNetwork = ref.watch(networkConnectionProvider).valueOrNull;
    final apiLabel = _apiReachable == null
        ? 'Not checked yet'
        : _apiReachable!
            ? (_serviceHealthy == true ? 'Service is healthy' : 'Service is responding with an issue')
            : 'Could not reach the service';
    final apiIcon = _apiReachable == null
        ? Icons.help_outline_rounded
        : _apiReachable!
            ? (_serviceHealthy == true
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded)
            : Icons.cloud_off_rounded;
    final apiColor = _apiReachable == null
        ? theme.colorScheme.onSurfaceVariant
        : _apiReachable!
            ? (_serviceHealthy == true
                ? theme.colorScheme.primary
                : theme.colorScheme.tertiary)
            : theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Connection diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device network', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    hasNetwork == null
                        ? 'Checking network availability…'
                        : hasNetwork
                            ? 'A network connection is available.'
                            : 'No network connection is available.',
                  ),
                  const Divider(height: 28),
                  Text('Veedufix service', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(apiIcon, color: apiColor),
                      const SizedBox(width: 10),
                      Expanded(child: Text(apiLabel)),
                    ],
                  ),
                  if (_responseTime != null) ...[
                    const SizedBox(height: 8),
                    Text('Response time: ${_responseTime!.inMilliseconds} ms'),
                  ],
                  if (_checkedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last checked ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_checkedAt!.toLocal()))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _checking ? null : _checkConnection,
                      icon: _checking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(_checking ? 'Checking…' : 'Check connection'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyReport(hasNetwork),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy diagnostics for support'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The service check uses the public health endpoint. The copied report contains connection status and app platform only; it does not include your account or booking details.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
