import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/features/auth/providers/auth_provider.dart';
import 'package:rms_offline/features/pos/providers/pos_provider.dart';
import 'package:rms_offline/database/restaurant_database.dart';

// ─── Period enum ─────────────────────────────────────────────────────────────

enum _Period { week, month, year }

// ─── Dashboard ───────────────────────────────────────────────────────────────

class RestaurantDashboard extends ConsumerStatefulWidget {
  const RestaurantDashboard({super.key});

  @override
  ConsumerState<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends ConsumerState<RestaurantDashboard> {
  _Period _period = _Period.week;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final ordersAsync = ref.watch(activeOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    Text(
                      "Your restaurant performance at a glance",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const Spacer(),
                _PeriodTabs(
                  selected: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Stats row ───────────────────────────────────────────────────
            statsAsync.when(
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: _DashCard(
                      icon: Icons.attach_money_rounded,
                      iconColor: AppTheme.primaryColor,
                      iconBg: const Color(0xFFEDE9FF),
                      title: 'Total Revenue',
                      value: '\$${(stats['todayRevenue'] as double? ?? 0).toStringAsFixed(2)}',
                      trend: '+0%',
                      trendLabel: 'vs last ${_period.name}',
                      positive: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DashCard(
                      icon: Icons.shopping_cart_rounded,
                      iconColor: AppTheme.successColor,
                      iconBg: const Color(0xFFD1FAE5),
                      title: 'Total Orders',
                      value: '${stats['todayOrders'] ?? 0}',
                      trend: '+0%',
                      trendLabel: 'vs last ${_period.name}',
                      positive: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DashCard(
                      icon: Icons.group_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'New Customers',
                      value: '0',
                      trend: '0%',
                      trendLabel: 'vs last ${_period.name}',
                      positive: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DashCard(
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFEDE9FE),
                      title: 'Average Order',
                      value: () {
                        final orders = stats['todayOrders'] as int? ?? 0;
                        final rev = stats['todayRevenue'] as double? ?? 0;
                        return '\$${orders > 0 ? (rev / orders).toStringAsFixed(2) : '0.00'}';
                      }(),
                      trend: '+0%',
                      trendLabel: 'vs last ${_period.name}',
                      positive: true,
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // ── Live alerts ──────────────────────────────────────────────────
            statsAsync.when(
              data: (stats) {
                final low = stats['lowStockCount'] as int? ?? 0;
                final pending = stats['pendingOrders'] as int? ?? 0;
                if (low == 0 && pending == 0) return const SizedBox.shrink();
                return Column(
                  children: [
                    Row(
                      children: [
                        if (pending > 0)
                          Expanded(
                            child: _AlertBanner(
                              icon: Icons.pending_actions_rounded,
                              color: AppTheme.warningColor,
                              text: '$pending orders are waiting to be prepared',
                              action: 'View Kitchen',
                              onAction: () => context.go('/kitchen'),
                            ),
                          ),
                        if (pending > 0 && low > 0) const SizedBox(width: 12),
                        if (low > 0)
                          Expanded(
                            child: _AlertBanner(
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.errorColor,
                              text: '$low ingredients are running low on stock',
                              action: 'View Inventory',
                              onAction: () => context.go('/inventory'),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Bottom section: chart + recent orders ────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sales chart placeholder
                Expanded(
                  flex: 3,
                  child: _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Overview',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Revenue trend for this ${_period.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const SizedBox(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bar_chart_rounded,
                                    size: 48, color: Color(0xFFD1D5DB)),
                                SizedBox(height: 12),
                                Text(
                                  'Chart will be displayed here',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Recent orders
                Expanded(
                  flex: 2,
                  child: _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Recent Orders',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/orders'),
                              child: const Text('View all',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ordersAsync.when(
                          data: (orders) {
                            if (orders.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text('No recent orders',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13)),
                                ),
                              );
                            }
                            return Column(
                              children: orders.take(6).map((o) {
                                final color = AppTheme.orderStatusColor(o.status);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ORD-${_formatDate(o.createdAt)}-${o.id.substring(0, 4).toUpperCase()}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Text(
                                                  '${o.totalAmount.toStringAsFixed(0)} items',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                                const Text(' • ',
                                                    style: TextStyle(
                                                        color: AppTheme
                                                            .textSecondary)),
                                                Text(
                                                  o.status[0].toUpperCase() +
                                                      o.status.substring(1),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: color,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${o.totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Text('Error: $e'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

// ─── Period tabs ──────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: _Period.values.map((p) {
          final active = p == selected;
          final label = p == _Period.week
              ? 'This Week'
              : p == _Period.month
                  ? 'This Month'
                  : 'This Year';
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  if (active)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.calendar_today_rounded,
                          size: 12, color: Colors.white),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : AppTheme.textSecondary,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Dashboard stat card ──────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String value;
  final String trend;
  final String trendLabel;
  final bool positive;

  const _DashCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.trend,
    required this.trendLabel,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: AppTheme.textSecondary, size: 18),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'details', child: Text('View Details')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 14,
                color: positive ? AppTheme.successColor : AppTheme.errorColor,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  color: positive ? AppTheme.successColor : AppTheme.errorColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(trendLabel,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String action;
  final VoidCallback onAction;
  const _AlertBanner({
    required this.icon,
    required this.color,
    required this.text,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.zero),
            child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: child,
    );
  }
}

