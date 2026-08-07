import 'package:dio/dio.dart';

class WorkerJobApi {
  WorkerJobApi(this._dio);

  final Dio _dio;

  Future<void> acceptJob(String bookingId) async {
    await _dio.post<dynamic>('/bookings/$bookingId/accept-job');
  }

  Future<void> declineJob(String offerId) async {
    await _dio.post<dynamic>('/users/me/worker/jobs/$offerId/decline');
  }

  Future<void> startEnRoute(String bookingId) async {
    await _dio.post<dynamic>('/bookings/$bookingId/en-route');
  }
}
