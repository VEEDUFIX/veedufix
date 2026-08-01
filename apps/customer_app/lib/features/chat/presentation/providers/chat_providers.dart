import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  factory ChatMessage.fromJson(String id, Map<dynamic, dynamic> json) {
    return ChatMessage(
      id: id,
      text: json['text'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int? ?? 0),
      isRead: json['isRead'] as bool? ?? false,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(ChatAttachment.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'attachments': attachments.map((attachment) => attachment.toJson()).toList(growable: false),
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

final chatProvider = StreamProvider.family<List<ChatMessage>, String>((ref, bookingId) {
  final refDb = FirebaseDatabase.instance.ref('chats/$bookingId');
  return refDb.onValue.map((event) {
    final map = event.snapshot.value as Map<dynamic, dynamic>?;
    if (map == null) return [];
    
    final messages = map.entries.map((e) {
      final val = e.value as Map<dynamic, dynamic>;
      return ChatMessage.fromJson(e.key.toString(), val);
    }).toList();
    
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  });
});

final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController();
});

class ChatController {
  Future<void> sendMessage({
    required String bookingId,
    required String text,
    required String senderId,
    List<ChatAttachment> attachments = const [],
  }) async {
    if (text.isEmpty && attachments.isEmpty) return;
    
    final refDb = FirebaseDatabase.instance.ref('chats/$bookingId').push();
    final message = ChatMessage(
      id: refDb.key!,
      text: text,
      senderId: senderId,
      timestamp: DateTime.now(),
      isRead: false,
      attachments: attachments,
    );
    
    await refDb.set(message.toJson());
  }

  Future<void> markAsRead({
    required String bookingId,
    required String userId,
  }) async {
    final refDb = FirebaseDatabase.instance.ref('chats/$bookingId');
    final snapshot = await refDb.get();
    final map = snapshot.value as Map<dynamic, dynamic>?;
    if (map == null) return;

    final updates = <String, Object?>{};
    for (final entry in map.entries) {
      final value = entry.value as Map<dynamic, dynamic>?;
      if (value == null) continue;
      final senderId = value['senderId'] as String?;
      final isRead = value['isRead'] as bool? ?? false;
      if (senderId != null && senderId != userId && !isRead) {
        updates['${entry.key}/isRead'] = true;
      }
    }

    if (updates.isNotEmpty) {
      await refDb.update(updates);
    }
  }
}
