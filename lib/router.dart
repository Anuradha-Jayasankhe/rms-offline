import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/customers/screens/customers_screen.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'features/kitchen/screens/kitchen_display_screen.dart';
import 'features/menu/screens/menu_screen.dart';
import 'features/orders/screens/orders_screen.dart';
import 'features/platform_admin/screens/platform_admin_screens.dart';
import 'features/pos/screens/pos_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/restaurant_owner/screens/restaurant_dashboard.dart';
import 'features/restaurant_owner/screens/staff_screen.dart';
import 'features/settings/screens/settings_screen.dart';
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
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // ─── Shell (all authenticated routes) ───────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          // Platform Admin routes
          GoRoute(
            path: '/admin',
            builder: (context, state) => const PlatformAdminDashboard(),
          ),
          GoRoute(
            path: '/admin/restaurants/create',
            builder: (context, state) => const CreateRestaurantScreen(),
          ),

          // Restaurant routes
          GoRoute(path: '/dashboard', builder: (context, state) => const RestaurantDashboard()),
          GoRoute(path: '/pos',       builder: (context, state) => const PosScreen()),
          GoRoute(path: '/billing',   builder: (context, state) => const PosScreen()),  // alias
          GoRoute(path: '/orders',    builder: (context, state) => const OrdersScreen()),
          GoRoute(path: '/menu',      builder: (context, state) => const MenuScreen()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen()),
          GoRoute(path: '/kitchen',   builder: (context, state) => const KitchenDisplayScreen()),
          GoRoute(path: '/staff',     builder: (context, state) => const StaffScreen()),
          GoRoute(path: '/customers', builder: (context, state) => const CustomersScreen()),
          GoRoute(path: '/reports',   builder: (context, state) => const ReportsScreen()),
          GoRoute(path: '/settings',  builder: (context, state) => const SettingsScreen()),
          // Placeholder routes
          GoRoute(
            path: '/tables',
            builder: (context, state) => const _ComingSoonPage(
                title: 'Tables & Rooms',
                icon: Icons.table_restaurant_rounded),
          ),
          GoRoute(
            path: '/bookings',
            builder: (context, state) => const _ComingSoonPage(
                title: 'Bookings',
                icon: Icons.event_note_rounded),
          ),
          GoRoute(
            path: '/plans',
            builder: (context, state) => const _ComingSoonPage(
                title: 'Subscription Plans',
                icon: Icons.credit_card_rounded),
          ),
          GoRoute(
            path: '/docs',
            builder: (context, state) => const _ComingSoonPage(
                title: 'Documentation',
                icon: Icons.menu_book_rounded),
          ),
          GoRoute(
            path: '/support',
            builder: (context, state) => const _ComingSoonPage(
                title: 'Support',
                icon: Icons.support_agent_rounded),
          ),
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
            Text('Page not found: ${state.matchedLocation}'),
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

// ─── Coming Soon placeholder ──────────────────────────────────────────────────

class _ComingSoonPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ComingSoonPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF5C35CC).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 40, color: const Color(0xFF5C35CC)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            const SizedBox(height: 8),
            const Text('This feature is coming soon',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
