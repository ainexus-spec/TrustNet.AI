import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/onboarding/auth_wrapper.dart';
import '../screens/onboarding/role_selection_screen.dart';
import '../screens/onboarding/login_screen.dart';
import '../screens/onboarding/register_screen.dart';
// Business
import '../screens/business/business_dashboard_screen.dart';
import '../screens/business/track_shipment_screen.dart';
import '../screens/business/track_screen.dart';
import '../screens/business/trust_score_screen.dart';
import '../screens/business/ai_risk_report_screen.dart';
import '../screens/business/network_trust_screen.dart';
import '../screens/business/smart_assignment_screen.dart';
import '../screens/business/shipment_qr_screen.dart';
import '../screens/business/view_epod_screen.dart';
import '../screens/transporter/transporter_dashboard_screen.dart';
import '../screens/transporter/create_shipment_screen.dart';
import '../screens/transporter/transporter_marketplace_screen.dart';
import '../screens/transporter/update_status_screen.dart';
import '../screens/transporter/upload_epod_screen.dart';
import '../screens/transporter/ai_trust_report_screen.dart';
// Shared Profiles & Settings
import '../screens/shared/shared_screens.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/change_password_screen.dart';
import '../screens/profile/settings_screens.dart';

// ─── Auth-aware refresh notifier ──────────────────────────────────────────────
// GoRouter re-evaluates its `redirect` callback every time this notifier fires.
// We wire it to FirebaseAuth.authStateChanges() so logout triggers an immediate
// redirect to '/' without any manual navigation.
class _AuthStateNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;

  _AuthStateNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('[AuthNotifier] Auth state changed → user: ${user?.uid ?? "null"}');
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class AppRouter {
  /// Routes that are accessible WITHOUT authentication
  static const _publicPaths = <String>{
    '/',              // AuthWrapper — decides login vs dashboard
    '/role-selection',
    '/login',
    '/register',
  };

  static final _authNotifier = _AuthStateNotifier();

  static final router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: _authNotifier,

    // ── Auth redirect guard ──────────────────────────────────────────────
    // Runs on EVERY navigation AND whenever _authNotifier fires (login/logout).
    // If logged out + on a protected route → force back to '/' (AuthWrapper).
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final currentPath = state.uri.path;
      final isPublicRoute = _publicPaths.contains(currentPath);

      debugPrint('[Router Redirect] loggedIn=$loggedIn, path=$currentPath, isPublic=$isPublicRoute');

      // NOT logged in & trying to access a protected route → kick to AuthWrapper
      if (!loggedIn && !isPublicRoute) {
        debugPrint('[Router Redirect] → Redirecting to / (not authenticated)');
        return '/';
      }

      return null; // no redirect needed
    },

    routes: [
      // ── Root: AuthWrapper ──────────────────────────
      // Uses authStateChanges() StreamBuilder to decide:
      //   • null user  → RoleSelectionScreen
      //   • valid user → navigate to /business/dashboard or /transporter/dashboard
      GoRoute(path: '/', builder: (c, s) => const AuthWrapper()),
      GoRoute(path: '/role-selection', builder: (c, s) => const RoleSelectionScreen()),
      GoRoute(
        path: '/login',
        builder: (c, s) {
          final role = s.extra as String? ?? 'business';
          return LoginScreen(role: role);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (c, s) {
          final role = s.extra as String? ?? 'business';
          return RegisterScreen(role: role);
        },
      ),

      // ── Business Routes ───────────────────────────
      GoRoute(path: '/business/dashboard', builder: (c, s) => const BusinessDashboardScreen()),
      GoRoute(path: '/business/create', builder: (c, s) => const CreateShipmentScreen()),
      GoRoute(path: '/business/track', builder: (c, s) => const TrackScreen()),
      GoRoute(
        path: '/business/track/:id',
        builder: (c, s) => TrackShipmentScreen(shipmentId: s.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/business/update/:id',
        builder: (c, s) => UpdateStatusScreen(shipmentId: s.pathParameters['id'] ?? 'SH001'),
      ),
      GoRoute(
        path: '/business/epod/:id',
        builder: (c, s) => UploadEPODScreen(shipmentId: s.pathParameters['id'] ?? 'SH001'),
      ),
      GoRoute(path: '/business/trust-score', builder: (c, s) => const TrustScoreScreen()),
      GoRoute(path: '/business/risk-report', builder: (c, s) => const AIRiskReportScreen()),
      GoRoute(path: '/business/network-trust', builder: (c, s) => const NetworkTrustScreen()),
      GoRoute(path: '/business/smart-assign', builder: (c, s) => const SmartAssignmentScreen()),
      GoRoute(
        path: '/business/qr/:id',
        builder: (c, s) => ShipmentQRScreen(shipmentId: s.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/business/view-epod/:id',
        builder: (c, s) => ViewEPODScreen(shipmentId: s.pathParameters['id'] ?? ''),
      ),

      // ── Transporter Routes ────────────────────────
      GoRoute(path: '/transporter/dashboard', builder: (c, s) => const TransporterDashboardScreen()),
      GoRoute(path: '/transporter/marketplace', builder: (c, s) => const TransporterMarketplaceScreen()),
      GoRoute(path: '/transporter/create', builder: (c, s) => const CreateShipmentScreen()),
      GoRoute(
        path: '/transporter/update-status/:shipmentId',
        builder: (context, state) {
          final shipmentId = state.pathParameters['shipmentId']!;
          return UpdateStatusScreen(shipmentId: shipmentId);
        },
      ),
      GoRoute(
        path: '/transporter/epod/:id',
        builder: (c, s) => UploadEPODScreen(shipmentId: s.pathParameters['id'] ?? 'SH001'),
      ),
      GoRoute(
        path: '/transporter/upload-epod/:shipmentId',
        builder: (context, state) {
          final shipmentId = state.pathParameters['shipmentId']!;
          return UploadEPODScreen(shipmentId: shipmentId);
        },
      ),
      GoRoute(path: '/transporter/ai-report', builder: (c, s) => const AITrustReportScreen()),

      // ── Shared Routes ─────────────────────────────
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/shipment-history', builder: (c, s) => const ShipmentHistoryScreen()),
      
      // ── Profile Sub-Routes ────────────────────────
      GoRoute(path: '/profile/edit', builder: (c, s) => const EditProfileScreen()),
      GoRoute(path: '/profile/change-password', builder: (c, s) => const ChangePasswordScreen()),
      GoRoute(path: '/profile/notifications', builder: (c, s) => const NotificationSettingsScreen()),
      GoRoute(path: '/profile/help', builder: (c, s) => const HelpSupportScreen()),
      GoRoute(path: '/profile/privacy', builder: (c, s) => const PrivacyPolicyScreen()),
    ],
  );
}
