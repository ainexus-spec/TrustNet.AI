import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/user_provider.dart';
import 'splash_screen.dart';
import 'role_selection_screen.dart';

/// AuthWrapper — The single source of truth for auth-based routing.
///
/// Uses [FirebaseAuth.authStateChanges()] to reactively decide what the user
/// should see:
///   • ConnectionState.waiting → SplashScreen (loading)
///   • null user              → RoleSelectionScreen (login flow)
///   • valid user             → fetch role from Firestore → navigate to dashboard
///
/// IMPORTANT: This widget does NOT render dashboards directly. It navigates
/// via GoRouter so that all sub-navigation (context.push, context.go) works
/// correctly from dashboard screens.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('[AuthWrapper] connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}');

        // ── Still connecting (initial load / splash) ──────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(showAuthCheck: false);
        }

        // ── Not authenticated → show login flow ──────────────────────
        if (!snapshot.hasData || snapshot.data == null) {
          debugPrint('[AuthWrapper] No user → showing RoleSelectionScreen');
          return const RoleSelectionScreen();
        }

        // ── Authenticated → fetch role and navigate to correct dashboard ──
        debugPrint('[AuthWrapper] User found: ${snapshot.data!.uid} → loading role...');
        return _RoleBasedRouter(user: snapshot.data!);
      },
    );
  }
}

/// Fetches the user's role from Firestore and navigates to the correct
/// dashboard route via GoRouter. Shows splash while loading.
class _RoleBasedRouter extends StatefulWidget {
  final User user;
  const _RoleBasedRouter({required this.user});

  @override
  State<_RoleBasedRouter> createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<_RoleBasedRouter> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _loadProfileAndNavigate();
  }

  Future<void> _loadProfileAndNavigate() async {
    try {
      // Load user profile into provider
      final userProvider = context.read<UserProvider>();
      await userProvider.fetchUserProfile(widget.user.uid);

      if (!mounted || _navigated) return;

      final userModel = userProvider.user;

      if (userModel == null) {
        // Profile missing in Firestore — try reading directly
        debugPrint('[RoleBasedRouter] UserProvider returned null, reading Firestore directly...');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .get();

        if (!mounted || _navigated) return;

        if (!doc.exists) {
          debugPrint('[RoleBasedRouter] No Firestore profile found → signing out');
          userProvider.clearUser();
          await FirebaseAuth.instance.signOut();
          return;
        }

        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'] as String? ?? 'business';

        _navigated = true;
        debugPrint('[RoleBasedRouter] Firestore role=$role → navigating');
        _navigateToDashboard(role);
        return;
      }

      // Normal path — profile loaded successfully
      _navigated = true;
      debugPrint('[RoleBasedRouter] role=${userModel.role} → navigating to dashboard');
      _navigateToDashboard(userModel.role);
    } catch (e) {
      debugPrint('[RoleBasedRouter] Error loading profile: $e');
      if (mounted && !_navigated) {
        // On error, sign out so AuthWrapper shows login screen
        context.read<UserProvider>().clearUser();
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  void _navigateToDashboard(String role) {
    // Use addPostFrameCallback to navigate AFTER current build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (role == 'business') {
        context.go('/business/dashboard');
      } else {
        context.go('/transporter/dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash while loading profile / before navigation
    return const SplashScreen(showAuthCheck: false);
  }
}
