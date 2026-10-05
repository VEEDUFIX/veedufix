class WorkerSupportTicket {
  const WorkerSupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.replyCount = 0,
  });

  final String id;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final int replyCount;

  factory WorkerSupportTicket.fromJson(Map<String, dynamic> json) {
    return WorkerSupportTicket(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? 'Support ticket',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkerSupportReply {
  const WorkerSupportReply({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.authorName,
    required this.authorRole,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final String authorName;
  final String authorRole;

  factory WorkerSupportReply.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return WorkerSupportReply(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      authorName: author?['name'] as String? ?? 'Support',
      authorRole: author?['role'] as String? ?? 'ADMIN',
    );
  }
}

class WorkerSupportThread {
  const WorkerSupportThread({required this.ticket, required this.replies});

  final WorkerSupportTicket ticket;
  final List<WorkerSupportReply> replies;

  factory WorkerSupportThread.fromJson(Map<String, dynamic> json) {
    final replies = (json['replies'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((reply) => reply['isInternal'] != true)
        .map(WorkerSupportReply.fromJson)
        .toList(growable: false);
    return WorkerSupportThread(
      ticket: WorkerSupportTicket.fromJson(json),
      replies: replies,
    );
  }
}
