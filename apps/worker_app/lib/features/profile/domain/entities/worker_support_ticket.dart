class WorkerSupportTicket {
  const WorkerSupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;

  factory WorkerSupportTicket.fromJson(Map<String, dynamic> json) {
    return WorkerSupportTicket(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? 'Support ticket',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
