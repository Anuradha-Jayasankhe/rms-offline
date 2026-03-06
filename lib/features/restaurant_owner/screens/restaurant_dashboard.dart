import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/features/auth/providers/auth_provider.dart';
import 'package:rms_offline/features/pos/providers/pos_provider.dart';
import 'package:rms_offline/widgets/common_widgets.dart';

/// Owner/Staff dashboard with stats
class RestaurantDashboard extends ConsumerWidget {
  const RestaurantDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dashboard',
                              style:
                                  Theme.of(context).textTheme.headlineLarge),
                          Text(
                            "Welcome back, ${auth.name ?? 'User'}",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SyncStatusWidget(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  statsAsync.when(
                    data: (stats) => Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 220,
                          child: StatCard(
                            title: "Today's Orders",
                            value: '${stats['todayOrders'] ?? 0}',
                            icon: Icons.receipt_long,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: StatCard(
                            title: "Today's Revenue",
                            value:
                                '\$${(stats['todayRevenue'] as double? ?? 0).toStringAsFixed(2)}',
                            icon: Icons.attach_money,
                            color: AppTheme.successColor,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: StatCard(
                            title: 'Pending Orders',
                            value: '${stats['pendingOrders'] ?? 0}',
                            icon: Icons.pending_actions,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: StatCard(
                            title: 'Preparing',
                            value: '${stats['preparingOrders'] ?? 0}',
                            icon: Icons.restaurant_menu,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: StatCard(
                            title: 'Low Stock Alerts',
                            value: '${stats['lowStockCount'] ?? 0}',
                            icon: Icons.warning_amber,
                            color: AppTheme.errorColor,
                            subtitle: 'Ingredients need restocking',
                          ),
                        ),
                      ],
                    ),
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 32),
                  Text('Active Orders',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  const Expanded(child: ActiveOrdersList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveOrdersList extends ConsumerWidget {
  const ActiveOrdersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(activeOrdersProvider);
    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                SizedBox(height: 12),
                Text('No active orders', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (ctx, i) {
            final order = orders[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.orderStatusColor(order.status).withValues(alpha: 0.15),
                  child: Icon(
                    Icons.receipt,
                    color: AppTheme.orderStatusColor(order.status),
                  ),
                ),
                title: Text(
                  'Order #${order.id.substring(0, 8)} — ${order.tableLabel ?? 'No table'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Items: ${order.totalAmount.toStringAsFixed(2)} | ${order.createdAt.toString().substring(0, 16)}',
                ),
                trailing: Chip(
                  label: Text(order.status.toUpperCase()),
                  backgroundColor: AppTheme.orderStatusColor(order.status)
                      .withValues(alpha: 0.1),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: AppTheme.orderStatusColor(order.status),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
