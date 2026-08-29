import 'package:web_socket_channel/web_socket_channel.dart';

Uri buildRealtimeUri({
  required String apiBaseUrl,
  required String path,
  Map<String, String>? queryParameters,
}) {
  final baseUri = Uri.parse(apiBaseUrl);
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return baseUri.replace(
    scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
    path: '${baseUri.path}$normalizedPath',
    queryParameters: queryParameters,
  );
}

WebSocketChannel connectTrackingSocket({
  required String apiBaseUrl,
  required String token,
  required String bookingId,
}) {
  return WebSocketChannel.connect(
    buildRealtimeUri(
      apiBaseUrl: apiBaseUrl,
      path: '/tracking/ws',
      queryParameters: {
        'bookingId': bookingId,
      },
    ),
    protocols: [token],
  );
}

WebSocketChannel connectNotificationSocket({
  required String apiBaseUrl,
  required String token,
}) {
  return WebSocketChannel.connect(
    buildRealtimeUri(
      apiBaseUrl: apiBaseUrl,
      path: '/notifications/ws',
    ),
    protocols: [token],
  );
}
