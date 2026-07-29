import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/booking/presentation/pages/bookings_page.dart';
import '../features/booking/presentation/pages/arrival_otp_page.dart';
import '../features/booking/presentation/pages/booking_rating_page.dart';
import '../features/booking/presentation/pages/completion_otp_page.dart';
import '../features/profile/presentation/pages/saved_addresses_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/shell/presentation/pages/app_shell_page.dart';
import '../features/catalog/presentation/pages/service_detail_page.dart';
import '../features/catalog/presentation/pages/professional_profile_page.dart';
import '../features/booking/presentation/pages/checkout_page.dart';
import '../features/cart/presentation/pages/cart_page.dart';
import '../features/tracking/presentation/pages/live_tracking_page.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/profile/presentation/pages/notifications_page.dart';
import '../features/profile/presentation/pages/referral_page.dart';
import '../features/profile/presentation/pages/support_page.dart';
import '../features/favorites/presentation/pages/favorites_page.dart';
import '../features/profile/presentation/pages/map_location_picker_page.dart';
import '../features/offers/presentation/pages/offers_page.dart';
import '../features/profile/presentation/pages/settings_page.dart';
import '../features/wallet/presentation/pages/wallet_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final session = authState.valueOrNull;

      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isAuthRoute = location == '/login' || location == '/otp';
      final homeRoute = homeRouteForMode(AppMode.customer);

      if (session == null) {
        return isAuthRoute ? null : '/login';
      }

      if (location == '/login' || location == '/otp' || location == '/splash') {
        return homeRoute;
      }

      if (!allowedRoutesForMode(AppMode.customer).contains(location)) {
        return homeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(mode: AppMode.customer),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpPage(),
      ),
      GoRoute(
        path: '/arrival-otp',
        builder: (context, state) {
          final bookingId = state.uri.queryParameters['bookingId'] ?? '';
          return ArrivalOtpPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/completion-otp',
        builder: (context, state) {
          final bookingId = state.uri.queryParameters['bookingId'] ?? '';
          return CompletionOtpPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/addresses',
        builder: (context, state) => const SavedAddressesPage(),
      ),
      GoRoute(
        path: '/booking-rating',
        builder: (context, state) {
          final bookingId = state.uri.queryParameters['bookingId'] ?? '';
          return BookingRatingPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/service',
        builder: (context, state) {
          final serviceId = state.uri.queryParameters['id'] ?? '';
          return ServiceDetailPage(serviceId: serviceId);
        },
      ),
      GoRoute(
        path: '/professional',
        builder: (context, state) {
          final proId = state.uri.queryParameters['id'] ?? '';
          return ProfessionalProfilePage(professionalId: proId);
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) {
          return const CartPage();
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          return const CheckoutPage();
        },
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) {
          final bookingId = state.uri.queryParameters['bookingId'] ?? '';
          return LiveTrackingPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final bookingId = state.uri.queryParameters['bookingId'] ?? '';
          return ChatPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/offers',
        builder: (context, state) => const OffersPage(),
      ),
      GoRoute(
        path: '/referral',
        builder: (context, state) => const ReferralPage(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletPage(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
        path: '/map-picker',
        builder: (context, state) => const MapLocationPickerPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShellPage(child: child),
        routes: [
          GoRoute(
            path: '/app',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/bookings',
            builder: (context, state) => const BookingsPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}
