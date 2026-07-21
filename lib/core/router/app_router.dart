import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/role_select_screen.dart';
import '../../features/auth/presentation/screens/verification_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../features/marketplace/presentation/screens/listing_detail_screen.dart';
import '../../features/marketplace/presentation/screens/create_listing_screen.dart';
import '../../features/marketplace/presentation/screens/orders_screen.dart';
import '../../features/marketplace/presentation/screens/order_detail_screen.dart';
import '../../features/consultation/presentation/screens/experts_screen.dart';
import '../../features/consultation/presentation/screens/expert_profile_screen.dart';
import '../../features/consultation/presentation/screens/consultation_room_screen.dart';
import '../../features/transport/presentation/screens/transport_screen.dart';
import '../../features/transport/presentation/screens/transport_job_detail_screen.dart';
import '../../features/transport/presentation/screens/create_transport_job_screen.dart';
import '../../features/knowledge/presentation/screens/knowledge_screen.dart';
import '../../features/knowledge/presentation/screens/knowledge_post_screen.dart';
import '../../features/knowledge/presentation/screens/courses_screen.dart';
import '../../features/knowledge/presentation/screens/course_detail_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/setup_expert_profile_screen.dart';
import '../../features/profile/presentation/screens/setup_farmer_profile_screen.dart';
import '../../features/profile/presentation/screens/setup_driver_profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../constants/app_constants.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  // Listen to auth changes and refresh router
  final router = GoRouter(
    initialLocation: AppConstants.routeSplash,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final isAuthenticated = authState.value != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/' ||
          loc.startsWith('/login') ||
          loc.startsWith('/register') ||
          loc.startsWith('/onboarding') ||
          loc.startsWith('/role-select') ||
          loc.startsWith('/verification');

      // Not logged in and trying to access protected route → go to login
      if (!isAuthenticated && !isAuthRoute) {
        return AppConstants.routeLogin;
      }

      // Logged in and on auth route (except splash) → go to home
      if (isAuthenticated &&
          (loc.startsWith('/login') || loc.startsWith('/register'))) {
        return AppConstants.routeHome;
      }

      return null;
    },
    routes: [
      // ── Auth routes ──────────────────────────────────
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/role-select',
        builder: (_, __) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/verification',
        builder: (_, __) => const VerificationScreen(),
      ),

      // ── Shell (bottom nav) ───────────────────────────
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          // Home
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeTabContent(),
          ),

          // Marketplace
          GoRoute(
            path: '/marketplace',
            builder: (_, __) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: '/marketplace/create',
            builder: (_, __) => const CreateListingScreen(),
          ),
          GoRoute(
            path: '/marketplace/listing/:id',
            builder: (_, state) => ListingDetailScreen(
                listingId: state.pathParameters['id']!),
          ),

          // Orders
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (_, state) =>
                OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),

          // Experts / Consultations
          GoRoute(
            path: '/experts',
            builder: (_, __) => const ExpertsScreen(),
          ),
          GoRoute(
            path: '/experts/:id',
            builder: (_, state) =>
                ExpertProfileScreen(expertId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/experts/consultation/:id',
            builder: (_, state) => ConsultationRoomScreen(
                consultationId: state.pathParameters['id']!),
          ),

          // Transport
          GoRoute(
            path: '/transport',
            builder: (_, __) => const TransportScreen(),
          ),
          GoRoute(
            path: '/transport/create',
            builder: (_, __) => const CreateTransportJobScreen(),
          ),
          GoRoute(
            path: '/transport/:id',
            builder: (_, state) =>
                TransportJobDetailScreen(jobId: state.pathParameters['id']!),
          ),

          // Knowledge
          GoRoute(
            path: '/knowledge',
            builder: (_, __) => const KnowledgeScreen(),
          ),
          GoRoute(
            path: '/knowledge/post/:id',
            builder: (_, state) =>
                KnowledgePostScreen(postId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/knowledge/courses',
            builder: (_, __) => const CoursesScreen(),
          ),
          GoRoute(
            path: '/knowledge/courses/:id',
            builder: (_, state) =>
                CourseDetailScreen(courseId: state.pathParameters['id']!),
          ),

          // Wallet
          GoRoute(
            path: '/wallet',
            builder: (_, __) => const WalletScreen(),
          ),

          // Profile
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/profile/setup-farmer',
            builder: (_, __) => const SetupFarmerProfileScreen(),
          ),
          GoRoute(
            path: '/profile/setup-expert',
            builder: (_, __) => const SetupExpertProfileScreen(),
          ),
          GoRoute(
            path: '/profile/setup-driver',
            builder: (_, __) => const SetupDriverProfileScreen(),
          ),

          // Notifications
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0D1B18),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌾', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home',
                  style: TextStyle(color: Color(0xFF2DD4BF))),
            ),
          ],
        ),
      ),
    ),
  );
  return router;
});

// Notifier that triggers router refresh when auth state changes
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}
