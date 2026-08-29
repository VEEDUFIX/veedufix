import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    required this.isRead,
    required this.attachments,
  });

  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool isRead;
  final List<ChatAttachment> attachments;

  factory ChatMessage.fromApi(String id, Map<String, dynamic> json) {
    final createdAt = json['createdAt'] as String? ?? '';
    return ChatMessage(
      id: id,
      text: json['content'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      timestamp: DateTime.tryParse(createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: json['isRead'] as bool? ?? false,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(ChatAttachment.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': text,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
    };
  }
}

class ChatAttachment {
  ChatAttachment({
    required this.url,
    required this.kind,
    this.name,
    this.mimeType,
    this.size,
  });

  final String url;
  final String kind;
  final String? name;
  final String? mimeType;
  final int? size;

  factory ChatAttachment.fromJson(Map<dynamic, dynamic> json) => ChatAttachment(
        url: json['url'] as String? ?? '',
        kind: json['kind'] as String? ?? 'file',
        name: json['name'] as String?,
        mimeType: json['mimeType'] as String?,
        size: (json['size'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'kind': kind,
        if (name != null) 'name': name,
        if (mimeType != null) 'mimeType': mimeType,
        if (size != null) 'size': size,
      };
}

final chatProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, bookingId) async* {
  final api = ref.watch(apiClientProvider);

  while (true) {
    final data = await api.get('/chat/$bookingId');
    final chatRoom = data['chatRoom'] as Map<String, dynamic>?;
    final messages = (chatRoom?['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) {
      final message = Map<String, dynamic>.from(entry);
      final id = message['id'] as String? ?? '';
      return ChatMessage.fromApi(id, message);
    }).toList(growable: false)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    yield messages;
    await Future.delayed(const Duration(seconds: 3));
  }
});

final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController(ref.watch(apiClientProvider));
});

class ChatController {
  ChatController(this._api);

  final ApiClient _api;

  Future<ChatAttachment> uploadAttachment({
    required String bookingId,
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _api.post(
      '/upload/chat-attachment',
      data: FormData.fromMap({
        'bookingId': bookingId,
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );

    final attachment = response['attachment'] as Map<String, dynamic>?;
    if (attachment == null) {
      throw Exception('Upload failed: attachment data was missing.');
    }

    return ChatAttachment(
      url: attachment['url'] as String? ?? '',
      kind: attachment['kind'] as String? ?? 'image',
      name: attachment['name'] as String?,
      mimeType: attachment['mimeType'] as String?,
      size: (attachment['size'] as num?)?.toInt(),
    );
  }

  Future<void> sendMessage({
    required String bookingId,
    required String text,
    required String senderId,
    List<ChatAttachment> attachments = const [],
  }) async {
    if (text.isEmpty && attachments.isEmpty) return;

    await _api.post(
      '/chat/$bookingId/messages',
      data: {
        'content': text,
        'attachments': attachments
            .map((attachment) => attachment.toJson())
            .toList(growable: false),
      },
    );
  }

  Future<void> markAsRead({
    required String bookingId,
    required String userId,
  }) async {
    await _api.post('/chat/$bookingId/read', data: {});
  }
}
