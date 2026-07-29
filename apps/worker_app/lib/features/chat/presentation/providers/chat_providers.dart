import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
  });

  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;

  factory ChatMessage.fromJson(String id, Map<dynamic, dynamic> json) {
    return ChatMessage(
      id: id,
      text: json['text'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int? ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
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
  }) async {
    if (text.isEmpty) return;
    
    final refDb = FirebaseDatabase.instance.ref('chats/$bookingId').push();
    final message = ChatMessage(
      id: refDb.key!,
      text: text,
      senderId: senderId,
      timestamp: DateTime.now(),
    );
    
    await refDb.set(message.toJson());
  }
}
