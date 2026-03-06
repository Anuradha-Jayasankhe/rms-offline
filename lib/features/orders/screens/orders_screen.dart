import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/features/auth/providers/auth_provider.dart';

// ─── Orders Provider ─────────────────────────────────────────────────────────

final allOrdersProvider = StreamProvider<List<Order>>((ref) {
  final restaurantId = ref.watch(currentRestaurantIdProvider);
  if (restaurantId == null) return const Stream.empty();
  final db = ref.watch(databaseManagerProvider).getRestaurantDatabase(restaurantId);
  return (db.select(db.orders)
        ..orderBy([(o) => drift.OrderingTerm.desc(o.createdAt)]))
      .watch();
});

// ─── Orders Screen ───────────────────────────────────────────────────────────

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _filterStatus = 'all';
  String _searchQuery = '';

  static const _statuses = ['all', 'pending', 'preparing', 'ready', 'served', 'cancelled'];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(allOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Padding(
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
                    Text('Orders', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    const Text('Manage and track all orders',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Stat chips ────────────────────────────────────────────────
            ordersAsync.when(
              data: (orders) => Row(
                children: [
                  _StatChip('Total', orders.length, Colors.blue),
                  const SizedBox(width: 8),
                  _StatChip('Pending', orders.where((o) => o.status == 'pending').length, AppTheme.warningColor),
                  const SizedBox(width: 8),
                  _StatChip('Preparing', orders.where((o) => o.status == 'preparing').length, const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _StatChip('Ready', orders.where((o) => o.status == 'ready').length, AppTheme.successColor),
                  const SizedBox(width: 8),
                  _StatChip('Served', orders.where((o) => o.status == 'served').length, AppTheme.textSecondary),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // ── Filters ───────────────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search orders...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 6,
                  children: _statuses.map((s) {
                    final active = _filterStatus == s;
                    return GestureDetector(
                      onTap: () => setState(() => _filterStatus = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppTheme.primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? AppTheme.primaryColor : AppTheme.borderColor,
                          ),
                        ),
                        child: Text(
                          s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1),
                          style: TextStyle(
                            color: active ? Colors.white : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Table ─────────────────────────────────────────────────────
            Expanded(
              child: ordersAsync.when(
                data: (allOrders) {
                  final filtered = allOrders.where((o) {
                    final matchStatus = _filterStatus == 'all' || o.status == _filterStatus;
                    final matchSearch = _searchQuery.isEmpty ||
                        o.id.toLowerCase().contains(_searchQuery) ||
                        (o.tableLabel?.toLowerCase().contains(_searchQuery) ?? false);
                    return matchStatus && matchSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFFD1D5DB)),
                          SizedBox(height: 12),
                          Text('No orders found', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 24,
                          horizontalMargin: 20,
                          headingRowHeight: 44,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 64,
                          columns: const [
                            DataColumn(label: Text('ORDER ID')),
                            DataColumn(label: Text('TABLE')),
                            DataColumn(label: Text('ITEMS')),
                            DataColumn(label: Text('TOTAL'), numeric: true),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('PAYMENT')),
                            DataColumn(label: Text('DATE')),
                          ],
                          rows: filtered.map((o) {
                            final statusColor = AppTheme.orderStatusColor(o.status);
                            final payColor = o.paymentStatus == 'paid'
                                ? AppTheme.successColor
                                : o.paymentStatus == 'partial'
                                    ? AppTheme.warningColor
                                    : AppTheme.errorColor;
                            return DataRow(cells: [
                              DataCell(Text(
                                'ORD-${_fmtId(o)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              )),
                              DataCell(Text(o.tableLabel ?? '—',
                                  style: const TextStyle(fontSize: 13))),
                              DataCell(Text('—', style: const TextStyle(fontSize: 13))),
                              DataCell(Text(
                                '\$${o.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(AppTheme.statusBadge(
                                  o.status[0].toUpperCase() + o.status.substring(1),
                                  statusColor)),
                              DataCell(AppTheme.statusBadge(
                                  o.paymentStatus[0].toUpperCase() +
                                      o.paymentStatus.substring(1),
                                  payColor)),
                              DataCell(Text(_fmtDate(o.createdAt),
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textSecondary))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtId(Order o) {
    final d = o.createdAt;
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}-${o.id.substring(0, 4).toUpperCase()}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
