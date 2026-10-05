import 'package:dio/dio.dart';

class PayoutChangeRequest {
  const PayoutChangeRequest({
    required this.id,
    required this.createdAt,
    required this.workerName,
    required this.city,
    required this.phone,
    required this.email,
    required this.bankAccountNumber,
    required this.bankIfsc,
    required this.upiId,
  });

  final String id;
  final DateTime? createdAt;
  final String workerName;
  final String city;
  final String phone;
  final String email;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? upiId;

  factory PayoutChangeRequest.fromJson(Map<String, dynamic> json) {
    final worker = json['workerProfile'] as Map<String, dynamic>? ?? const {};
    final user = worker['user'] as Map<String, dynamic>? ?? const {};
    return PayoutChangeRequest(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      workerName: worker['fullName'] as String? ?? 'Worker',
      city: worker['city'] as String? ?? 'City not set',
      phone: user['phone'] as String? ?? 'Not provided',
      email: user['email'] as String? ?? 'Not provided',
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfsc: json['bankIfsc'] as String?,
      upiId: json['upiId'] as String?,
    );
  }
}

class PayoutChangesApi {
  PayoutChangesApi(this._dio);
  final Dio _dio;

  Future<List<PayoutChangeRequest>> fetchPending() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/worker-review/payout-changes/pending',
    );
    return (response.data?['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PayoutChangeRequest.fromJson)
        .toList(growable: false);
  }

  Future<void> approve(String id) async {
    await _dio.post<void>(
      '/admin/worker-review/payout-changes/${Uri.encodeComponent(id)}/approve',
    );
  }

  Future<void> reject(String id, String reason) async {
    await _dio.post<void>(
      '/admin/worker-review/payout-changes/${Uri.encodeComponent(id)}/reject',
      data: {'reason': reason},
    );
  }
}
