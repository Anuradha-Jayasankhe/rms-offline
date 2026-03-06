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
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Row(
              children: [
                _Sidebar(
                  collapsed: _sidebarCollapsed,
                  location: widget.location,
                  authState: authState,
                  onToggle: () =>
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(authState: authState),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final AuthState authState;
  const _TopBar({required this.authState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Spacer
          const Spacer(),
          // Notification bell
          _IconBtn(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
            badge: 3,
          ),
          const SizedBox(width: 4),
          // User avatar + info
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _showUserMenu(context, ref),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    (authState.name ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.name ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _roleLabel(authState.role),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _roleLabel(AuthRole role) {
    switch (role) {
      case AuthRole.platformAdmin: return 'Platform Admin';
      case AuthRole.owner:         return 'Owner';
      case AuthRole.staff:         return 'Staff';
      case AuthRole.kitchen:       return 'Kitchen';
      case AuthRole.cashier:       return 'Cashier';
      default:                     return '';
    }
  }

  void _showUserMenu(BuildContext context, WidgetRef ref) {
    final RenderBox btn = context.findRenderObject() as RenderBox;
    final Offset offset = btn.localToGlobal(Offset(btn.size.width, btn.size.height));
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          offset.dx - 160, offset.dy, offset.dx, offset.dy + 100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          child: const Row(children: [
            Icon(Icons.person_outline, size: 18),
            SizedBox(width: 8),
            Text('Profile'),
          ]),
          onTap: () {},
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          child: const Row(children: [
            Icon(Icons.logout, size: 18, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Logout', style: TextStyle(color: AppTheme.errorColor)),
          ]),
          onTap: () => ref.read(authProvider.notifier).logout(),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;
  const _IconBtn({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon, size: 22, color: AppTheme.textSecondary),
          onPressed: onTap,
          tooltip: '',
        ),
        if (badge != null && badge! > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  final bool collapsed;
  final String location;
  final AuthState authState;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.collapsed,
    required this.location,
    required this.authState,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = collapsed ? 64.0 : 240.0;
    final isPlatformAdmin = authState.isPlatformAdmin;
    final isOwner = authState.isOwner;
    final role = authState.role;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: w,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(right: BorderSide(color: Color(0xFF2D2B5A), width: 1)),
      ),
      child: Column(
        children: [
          // ── Brand ──────────────────────────────────────────────────────────
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 18),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPlatformAdmin ? 'RMS Admin' : (authState.name ?? 'Restaurant'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isPlatformAdmin ? 'Platform Admin' : 'Restaurant',
                          style: const TextStyle(color: Color(0xFF8B8DB8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: const Color(0xFF8B8DB8),
                    size: 20,
                  ),
                  onPressed: onToggle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2D2B5A), height: 1),

          // ── Nav items ──────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (isPlatformAdmin) ...[
                  _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/admin', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.store_rounded, label: 'Restaurants', route: '/admin', location: location, collapsed: collapsed),
                ] else ...[
                  _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.kitchen_rounded, label: 'Kitchen', route: '/kitchen', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.add_circle_outline_rounded, label: 'New Order', route: '/pos', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.receipt_long_rounded, label: 'Billing', route: '/billing', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.shopping_cart_outlined, label: 'Orders', route: '/orders', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.table_restaurant_rounded, label: 'Tables', route: '/tables', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.event_note_rounded, label: 'Bookings', route: '/bookings', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.inventory_2_rounded, label: 'Inventory', route: '/inventory', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.people_outline_rounded, label: 'Customers', route: '/customers', location: location, collapsed: collapsed),
                  if (isOwner || role == AuthRole.staff)
                    _NavItem(icon: Icons.restaurant_menu_rounded, label: 'Menu', route: '/menu', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.bar_chart_rounded, label: 'Reports', route: '/reports', location: location, collapsed: collapsed),
                  if (!collapsed)
                    _SectionLabel('ADMIN'),
                  if (isOwner) ...[
                    _NavItem(icon: Icons.group_rounded, label: 'Users', route: '/staff', location: location, collapsed: collapsed),
                    _NavItem(icon: Icons.credit_card_rounded, label: 'Plans', route: '/plans', location: location, collapsed: collapsed),
                    _NavItem(icon: Icons.settings_rounded, label: 'Settings', route: '/settings', location: location, collapsed: collapsed),
                  ],
                  if (!collapsed)
                    _SectionLabel('HELP'),
                  _NavItem(icon: Icons.menu_book_rounded, label: 'Documentation', route: '/docs', location: location, collapsed: collapsed),
                  _NavItem(icon: Icons.support_agent_rounded, label: 'Support', route: '/support', location: location, collapsed: collapsed),
                ],
              ],
            ),
          ),

          // ── Logout ─────────────────────────────────────────────────────────
          const Divider(color: Color(0xFF2D2B5A), height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _NavItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              route: '',
              location: '',
              collapsed: collapsed,
              onTap: () => ref.read(authProvider.notifier).logout(),
              isLogout: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5E5F8A),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String route;
  final String location;
  final bool collapsed;
  final VoidCallback? onTap;
  final bool isLogout;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.location,
    required this.collapsed,
    this.onTap,
    this.isLogout = false,
  });

  bool get _isActive => !isLogout && location == route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = _isActive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap ?? () {
            if (route.isNotEmpty) context.go(route);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primaryColor
                  : isLogout
                      ? Colors.transparent
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active
                      ? Colors.white
                      : isLogout
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF8B8DB8),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : isLogout
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFB0B2D0),
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
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
