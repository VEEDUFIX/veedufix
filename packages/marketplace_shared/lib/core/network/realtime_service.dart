import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/environment.dart';
import '../storage/secure_store.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(
    environment: ref.watch(environmentProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});

class RealtimeService {
  RealtimeService({
    required AppEnvironment environment,
    required SecureStore secureStore,
  })  : _environment = environment,
        _secureStore = secureStore;

  final AppEnvironment _environment;
  final SecureStore _secureStore;

  WebSocketChannel? _trackingChannel;
  WebSocketChannel? _notificationChannel;
  
  final _trackingStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get trackingStream => _trackingStreamController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationStreamController.stream;

  String get _wsBaseUrl {
    if (_environment.apiBaseUrl.startsWith('https')) {
      return _environment.apiBaseUrl.replaceFirst('https', 'wss');
    }
    return _environment.apiBaseUrl.replaceFirst('http', 'ws');
  }

  Future<void> connectTracking(String bookingId) async {
    await disconnectTracking();
    final token = await _secureStore.readAccessToken();
    if (token == null) return;

    final url = Uri.parse('$_wsBaseUrl/tracking/ws?bookingId=$bookingId');
    _trackingChannel = WebSocketChannel.connect(url, protocols: [token]);
    
    _trackingChannel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          if (data['type'] == 'tracking.event') {
            _trackingStreamController.add(data['payload'] as Map<String, dynamic>);
          }
        } catch (_) {}
      },
      onDone: () {},
      onError: (_) {},
    );
  }

  void sendLocationUpdate(double lat, double lng) {
    if (_trackingChannel != null) {
      final msg = jsonEncode({
        'type': 'location.update',
        'payload': {
          'lat': lat,
          'lng': lng,
        },
      });
      _trackingChannel!.sink.add(msg);
    }
  }

  Future<void> disconnectTracking() async {
    await _trackingChannel?.sink.close();
    _trackingChannel = null;
  }

  Future<void> connectNotifications() async {
    await disconnectNotifications();
    final token = await _secureStore.readAccessToken();
    if (token == null) return;

    final url = Uri.parse('$_wsBaseUrl/notifications/ws');
    _notificationChannel = WebSocketChannel.connect(url, protocols: [token]);
    
    _notificationChannel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          if (data['type'] == 'notification.event') {
            _notificationStreamController.add(data['payload'] as Map<String, dynamic>);
          }
        } catch (_) {}
      },
      onDone: () {},
      onError: (_) {},
    );
  }

  Future<void> disconnectNotifications() async {
    await _notificationChannel?.sink.close();
    _notificationChannel = null;
  }
}
