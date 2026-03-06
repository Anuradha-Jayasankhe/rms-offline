import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/features/auth/providers/auth_provider.dart';
import 'package:rms_offline/widgets/common_widgets.dart';

// ─── App Shell ────────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(context, authState),
                const VerticalDivider(width: 1),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, AuthState authState) {
    final isPlatformAdmin = authState.isPlatformAdmin;
    final isOwner = authState.isOwner;
    final role = authState.role;

    return Container(
      width: 220,
      color: AppTheme.sidebarColor,
      child: Column(
        children: [
          // App brand header
          Container(
            height: 64,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RMS Offline',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        isPlatformAdmin
                            ? 'Platform Admin'
                            : authState.name ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                if (isPlatformAdmin) ...[
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    route: '/admin',
                    currentLocation: widget.location,
                  ),
                  _NavItem(
                    icon: Icons.store_outlined,
                    label: 'Restaurants',
                    route: '/admin',
                    currentLocation: widget.location,
                  ),
                ] else ...[
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    route: '/dashboard',
                    currentLocation: widget.location,
                  ),
                  _NavItem(
                    icon: Icons.point_of_sale_outlined,
                    label: 'POS',
                    route: '/pos',
                    currentLocation: widget.location,
                  ),
                  if (isOwner || role == AuthRole.staff) ...[
                    _NavItem(
                      icon: Icons.restaurant_menu_outlined,
                      label: 'Menu',
                      route: '/menu',
                      currentLocation: widget.location,
                    ),
                    _NavItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Inventory',
                      route: '/inventory',
                      currentLocation: widget.location,
                    ),
                  ],
                  if (role == AuthRole.kitchen ||
                      isOwner ||
                      role == AuthRole.staff)
                    _NavItem(
                      icon: Icons.kitchen_outlined,
                      label: 'Kitchen',
                      route: '/kitchen',
                      currentLocation: widget.location,
                    ),
                  if (isOwner)
                    _NavItem(
                      icon: Icons.people_outline,
                      label: 'Staff',
                      route: '/staff',
                      currentLocation: widget.location,
                    ),
                ],
              ],
            ),
          ),

          // Bottom section
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 4),
          // Sync status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: const SyncStatusWidget(),
          ),
          const SizedBox(height: 4),
          // User info + logout
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Text(
                    (authState.name ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    authState.name ?? 'User',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.white70,
                    size: 18,
                  ),
                  tooltip: 'Logout',
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentLocation;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
  });

  bool get _isActive =>
      currentLocation == route ||
      (route != '/' && currentLocation.startsWith(route));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: _isActive
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(route),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: _isActive ? Colors.white : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: _isActive ? Colors.white : Colors.white70,
                    fontWeight: _isActive ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                if (_isActive) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
