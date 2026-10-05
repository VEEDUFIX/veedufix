import 'package:marketplace_shared/marketplace_shared.dart';

/// Resolves notification data to a safe, app-internal worker route.
String workerNotificationRoute(Map<String, dynamic> payload) {
  final data = _asMap(payload['data']);
  final nested = _asMap(payload['payload']);
  final type = _firstString([
    payload['type'],
    payload['eventType'],
    payload['notificationType'],
    data['type'],
    data['eventType'],
    nested['type'],
    nested['eventType'],
    nested['notificationType'],
  ])?.toUpperCase();
  final bookingId = _firstString([
    payload['bookingId'],
    payload['booking_id'],
    data['bookingId'],
    data['booking_id'],
    nested['bookingId'],
    nested['booking_id'],
  ]);
  final safeBookingId = bookingId == null || bookingId.isEmpty
      ? null
      : Uri.encodeComponent(bookingId);

  switch (type) {
    case 'NEW_JOB':
    case 'JOB_ASSIGNED':
    case 'JOB_OFFER':
      return '/jobs';
    case 'CHAT':
      if (safeBookingId != null) return '/chat?bookingId=$safeBookingId';
      break;
    case 'PAYOUT':
    case 'EARNINGS':
    case 'PAYOUT_PENDING':
    case 'PAYOUT_SUCCESS':
    case 'PAYOUT_FAILED':
    case 'PAYOUT_REFUND':
      return '/wallet';
    case 'REVIEW':
    case 'NEW_REVIEW':
    case 'REVIEW_RESPONSE':
      return '/reviews';
    case 'WORKER_ONBOARDING_SUBMITTED':
    case 'WORKER_ONBOARDING_APPROVED':
    case 'WORKER_ONBOARDING_REJECTED':
    case 'WORKER_ONBOARDING_SUSPENDED':
    case 'WORKER_ONBOARDING_REINSTATED':
      return '/onboarding/status';
    case 'WORKER_PAYOUT_CHANGE_APPROVED':
    case 'WORKER_PAYOUT_CHANGE_REJECTED':
      return '/profile/payout-change';
    case 'JOB_UPDATE':
    case 'BOOKING_DETAIL':
    case 'WORKER_EN_ROUTE':
    case 'WORKER_ARRIVED':
      if (safeBookingId != null) {
        return '/job-execution?bookingId=$safeBookingId';
      }
      return '/jobs';
  }

  final requestedRoute = _firstString([
    payload['route'],
    data['route'],
    nested['route'],
  ]);
  final routeUri = requestedRoute == null ? null : Uri.tryParse(requestedRoute);
  final isAllowedRoute = routeUri != null &&
      !routeUri.hasScheme &&
      !routeUri.hasAuthority &&
      routeUri.path.startsWith('/') &&
      allowedRoutesForMode(AppMode.worker).any(
        (path) => routeUri.path == path || routeUri.path.startsWith('$path/'),
      );
  return isAllowedRoute ? routeUri.toString() : '/notifications';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

String? _firstString(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
