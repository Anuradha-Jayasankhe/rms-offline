import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'features/kitchen/screens/kitchen_display_screen.dart';
import 'features/menu/screens/menu_screen.dart';
import 'features/platform_admin/screens/platform_admin_screens.dart';
import 'features/pos/screens/pos_screen.dart';
import 'features/restaurant_owner/screens/restaurant_dashboard.dart';
import 'features/restaurant_owner/screens/staff_screen.dart';
import 'widgets/app_shell.dart';

// ─── Router Provider ──────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    debugLogDiagnostics: false,
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final location = state.matchedLocation;
      final isLoginPage = location == '/login';

      if (!isAuthenticated && !isLoginPage) return '/login';
      if (isAuthenticated && isLoginPage) {
        return authState.isPlatformAdmin ? '/admin' : '/dashboard';
      }
      return null;
    },
    routes: [
      // ─── Login ──────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // ─── Platform Admin Shell ────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, state) => const PlatformAdminDashboard(),
          ),
          GoRoute(
            path: '/admin/restaurants/create',
            builder: (_, __) => const CreateRestaurantScreen(),
          ),

          // ─── Restaurant Routes ─────────────────────────────────────────
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const RestaurantDashboard(),
          ),
          GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
          GoRoute(path: '/menu', builder: (_, __) => const MenuScreen()),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/kitchen',
            builder: (_, __) => const KitchenDisplayScreen(),
          ),
          GoRoute(path: '/staff', builder: (_, __) => const StaffScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found: ${state.matchedLocation}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
