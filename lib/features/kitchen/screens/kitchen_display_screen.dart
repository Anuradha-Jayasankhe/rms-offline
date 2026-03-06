import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/features/kitchen/providers/kitchen_provider.dart';

// ─── Kitchen Display Screen ───────────────────────────────────────────────────

class KitchenDisplayScreen extends ConsumerWidget {
  const KitchenDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingOrdersProvider);
    final preparingAsync = ref.watch(preparingOrdersProvider);
    final readyAsync = ref.watch(readyOrdersProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Kitchen Display'),
        backgroundColor: AppTheme.sidebarColor,
        foregroundColor: Colors.white,
        actions: [
          // Auto-refresh indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Live', style: TextStyle(color: Colors.greenAccent)),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending column
            Expanded(
              child: _OrderColumn(
                title: 'Pending',
                color: AppTheme.warningColor,
                icon: Icons.hourglass_empty,
                asyncOrders: pendingAsync,
                actionLabel: 'Start Preparing',
                onAction: (orderId, ref) => ref
                    .read(kitchenNotifierProvider.notifier)
                    .markOrderPreparing(orderId),
              ),
            ),
            const SizedBox(width: 16),
            // Preparing column
            Expanded(
              child: _OrderColumn(
                title: 'Preparing',
                color: AppTheme.accentColor,
                icon: Icons.restaurant,
                asyncOrders: preparingAsync,
                actionLabel: 'Mark Ready',
                onAction: (orderId, ref) => ref
                    .read(kitchenNotifierProvider.notifier)
                    .markOrderReady(orderId),
              ),
            ),
            const SizedBox(width: 16),
            // Ready column
            Expanded(
              child: _OrderColumn(
                title: 'Ready',
                color: AppTheme.successColor,
                icon: Icons.check_circle,
                asyncOrders: readyAsync,
                actionLabel: 'Mark Served',
                onAction: (orderId, ref) => ref
                    .read(kitchenNotifierProvider.notifier)
                    .markOrderServed(orderId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Order Column ─────────────────────────────────────────────────────────────

class _OrderColumn extends ConsumerWidget {
  final String title;
  final Color color;
  final IconData icon;
  final AsyncValue<List<Order>> asyncOrders;
  final String actionLabel;
  final Future<void> Function(String orderId, WidgetRef ref) onAction;

  const _OrderColumn({
    required this.title,
    required this.color,
    required this.icon,
    required this.asyncOrders,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Column header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              asyncOrders.maybeWhen(
                data: (orders) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${orders.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Orders list
        Expanded(
          child: asyncOrders.when(
            data: (orders) {
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 48, color: color.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text(
                        'No orders',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (ctx, i) => _OrderCard(
                  order: orders[i],
                  color: color,
                  actionLabel: actionLabel,
                  onAction: (orderId) => onAction(orderId, ref),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────

class _OrderCard extends ConsumerWidget {
  final Order order;
  final Color color;
  final String actionLabel;
  final Future<void> Function(String orderId) onAction;

  const _OrderCard({
    required this.order,
    required this.color,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderItemsAsync = ref.watch(kitchenOrderItemsProvider(order.id));

    final elapsed = DateTime.now().difference(order.createdAt);
    final isOverdue = elapsed.inMinutes > 15;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Table ${order.tableLabel ?? order.tableId ?? '—'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${order.id.substring(0, 6).toUpperCase()}', // short order ref
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatElapsed(elapsed),
                    style: TextStyle(
                      color: isOverdue
                          ? AppTheme.errorColor
                          : Colors.grey.shade600,
                      fontWeight: isOverdue
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Order items
            orderItemsAsync.when(
              data: (items) => Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.menuItemName,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              Icon(
                                Icons.comment,
                                size: 14,
                                color: Colors.orange.shade400,
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            // Notes
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sticky_note_2,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.brown,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onAction(order.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ${d.inMinutes % 60}m ago';
  }
}
