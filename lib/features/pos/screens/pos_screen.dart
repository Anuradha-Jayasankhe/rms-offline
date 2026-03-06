import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/features/menu/providers/menu_provider.dart';
import 'package:rms_offline/features/pos/providers/pos_provider.dart';
import 'package:rms_offline/widgets/common_widgets.dart';

// ─── POS Main Screen (Table Selection + Order Entry) ─────────────────────────

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posState = ref.watch(posNotifierProvider);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Row(
              children: [
                // Left : Tables grid
                SizedBox(width: 320, child: _TablePanel()),
                const VerticalDivider(width: 1),
                // Middle: Menu items
                Expanded(child: _MenuPanel()),
                const VerticalDivider(width: 1),
                // Right: Cart / Order summary
                SizedBox(width: 320, child: _CartPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Table Panel ─────────────────────────────────────────────────────────────

class _TablePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    final posState = ref.watch(posNotifierProvider);

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.sidebarColor,
            width: double.infinity,
            child: const Text(
              'TABLES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: tablesAsync.when(
              data: (tables) => GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: tables.length,
                itemBuilder: (ctx, i) {
                  final table = tables[i];
                  final isSelected = posState.selectedTableId == table.id;
                  final color = AppTheme.tableStatusColor(table.status);
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(posNotifierProvider.notifier)
                          .selectTable(table.id, table.tableLabel);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : color.withValues(alpha: 0.1),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : color,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_restaurant,
                            color: isSelected ? Colors.white : color,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            table.tableLabel,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            table.status.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : color,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu Panel ───────────────────────────────────────────────────────────────

class _MenuPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends ConsumerState<_MenuPanel> {
  String? _selectedCategory;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final menuAsync = ref.watch(menuItemsProvider(_selectedCategory));
    final posState = ref.watch(posNotifierProvider);

    return Column(
      children: [
        // Header + search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                posState.selectedTableName != null
                    ? 'Menu — ${posState.selectedTableName}'
                    : 'Select a table first',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search menu...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ],
          ),
        ),
        // Category chips
        categoriesAsync.when(
          data: (cats) => Container(
            height: 48,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...cats.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c.name),
                      selected: _selectedCategory == c.id,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = c.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox(height: 48),
          error: (_, __) => const SizedBox(height: 48),
        ),
        const Divider(height: 1),
        // Menu grid
        Expanded(
          child: menuAsync.when(
            data: (items) {
              final filtered = _search.isEmpty
                  ? items
                  : items
                        .where(
                          (i) => i.name.toLowerCase().contains(
                            _search.toLowerCase(),
                          ),
                        )
                        .toList();
              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'No menu items',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final item = filtered[i];
                  return _MenuItemCard(item: item);
                },
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

class _MenuItemCard extends ConsumerWidget {
  final MenuItem item;
  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posState = ref.watch(posNotifierProvider);
    final isInCart = posState.cartItems.any((c) => c.menuItemId == item.id);

    return GestureDetector(
      onTap: () {
        if (posState.selectedTableId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a table first')),
          );
          return;
        }
        ref.read(posNotifierProvider.notifier).addToCart(item);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isInCart
              ? AppTheme.primaryColor.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInCart ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isInCart ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.fastfood,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${item.sellingPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cart Panel ───────────────────────────────────────────────────────────────

class _CartPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posState = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.sidebarColor,
            width: double.infinity,
            child: Row(
              children: [
                const Text(
                  'ORDER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (posState.cartItems.isNotEmpty)
                  TextButton(
                    onPressed: notifier.clearCart,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          if (posState.selectedTableName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              width: double.infinity,
              child: Text(
                'Table: ${posState.selectedTableName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
          // Cart items
          Expanded(
            child: posState.cartItems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Cart is empty',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select a table then add items',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: posState.cartItems.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (ctx, i) {
                      final item = posState.cartItems[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.menuItemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '\$${item.unitPrice.toStringAsFixed(2)} each',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Qty control
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20,
                                  ),
                                  onPressed: () => notifier.updateCartItemQty(
                                    item.menuItemId,
                                    item.quantity - 1,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                  onPressed: () => notifier.updateCartItemQty(
                                    item.menuItemId,
                                    item.quantity + 1,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\$${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Bill summary
          if (posState.cartItems.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _BillRow(label: 'Subtotal', value: posState.subtotal),
                  _BillRow(label: 'Tax (10%)', value: posState.taxAmount),
                  const Divider(height: 16),
                  _BillRow(
                    label: 'TOTAL',
                    value: posState.totalAmount,
                    isBold: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: posState.isLoading
                          ? null
                          : () => _placeOrder(context, ref),
                      icon: posState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Place Order'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, WidgetRef ref) async {
    final orderId = await ref.read(posNotifierProvider.notifier).createOrder();
    if (orderId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order placed! ID: ${orderId.substring(0, 8)}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Pay',
            textColor: Colors.white,
            onPressed: () => _showPaymentDialog(context, ref, orderId),
          ),
        ),
      );
    }
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, String orderId) {
    String method = 'cash';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Process Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total: \$${ref.read(posNotifierProvider).totalAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                ],
                onChanged: (v) => setState(() => method = v ?? method),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final total = ref.read(posNotifierProvider).totalAmount;
                await ref
                    .read(posNotifierProvider.notifier)
                    .processPayment(
                      orderId: orderId,
                      paymentMethod: method,
                      paidAmount: total,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment processed! Order completed.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;

  const _BillRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: isBold ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}
