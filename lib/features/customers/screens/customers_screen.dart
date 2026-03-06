import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/features/customers/providers/customers_provider.dart';

// ─── Customers Screen ────────────────────────────────────────────────────────

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);

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
                    Text('Customers', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    const Text('Manage your customer relationships and loyalty',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showCustomerDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Customer'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Stats ────────────────────────────────────────────────────
            customersAsync.when(
              data: (customers) {
                final now = DateTime.now();
                final thisMonth = customers.where((c) =>
                    c.createdAt.month == now.month && c.createdAt.year == now.year);
                final returning = customers.where((c) => c.totalOrders > 1);
                final totalSpent = customers.fold<double>(
                    0, (sum, c) => sum + c.totalSpent);
                final avgSpent = customers.isNotEmpty
                    ? totalSpent / customers.length
                    : 0.0;

                return Row(
                  children: [
                    _StatBox('Total Customers', '${customers.length}', Colors.blue),
                    const SizedBox(width: 16),
                    _StatBox('New This Month', '${thisMonth.length}', AppTheme.primaryColor),
                    const SizedBox(width: 16),
                    _StatBox('Returning', '${returning.length}', AppTheme.successColor),
                    const SizedBox(width: 16),
                    _StatBox('Avg. Spent',
                        '\$${avgSpent.toStringAsFixed(2)}', AppTheme.errorColor),
                  ],
                );
              },
              loading: () => const SizedBox(height: 88),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // ── Search + Filter ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by name, phone or email...',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filter'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Table ─────────────────────────────────────────────────────
            Expanded(
              child: customersAsync.when(
                data: (allCustomers) {
                  final filtered = allCustomers.where((c) =>
                      _searchQuery.isEmpty ||
                      c.name.toLowerCase().contains(_searchQuery) ||
                      (c.email?.toLowerCase().contains(_searchQuery) ?? false) ||
                      (c.phone?.contains(_searchQuery) ?? false)).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 56, color: Color(0xFFD1D5DB)),
                          const SizedBox(height: 12),
                          const Text('No customers yet',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showCustomerDialog(context, ref),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add First Customer'),
                          ),
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
                          columnSpacing: 20,
                          horizontalMargin: 20,
                          headingRowHeight: 44,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 72,
                          columns: const [
                            DataColumn(label: Text('CUSTOMER')),
                            DataColumn(label: Text('CONTACT')),
                            DataColumn(label: Text('ORDERS'), numeric: true),
                            DataColumn(label: Text('TOTAL SPENT'), numeric: true),
                            DataColumn(label: Text('LOYALTY POINTS'), numeric: true),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filtered.map((c) {
                            return DataRow(cells: [
                              // Customer
                              DataCell(Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        AppTheme.primaryColor.withValues(alpha: 0.12),
                                    child: Text(
                                      c.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(c.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              )),
                              // Contact
                              DataCell(Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (c.email != null)
                                    Row(children: [
                                      const Icon(Icons.email_outlined,
                                          size: 12, color: AppTheme.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(c.email!,
                                          style: const TextStyle(
                                              fontSize: 12, color: AppTheme.textSecondary)),
                                    ]),
                                  if (c.phone != null)
                                    Row(children: [
                                      const Icon(Icons.phone_outlined,
                                          size: 12, color: AppTheme.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(c.phone!,
                                          style: const TextStyle(
                                              fontSize: 12, color: AppTheme.textSecondary)),
                                    ]),
                                ],
                              )),
                              // Orders
                              DataCell(Text('${c.totalOrders}',
                                  style: const TextStyle(fontSize: 13))),
                              // Total spent
                              DataCell(Text(
                                '\$${c.totalSpent.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              )),
                              // Loyalty points
                              DataCell(Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 14, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 4),
                                  Text('${c.loyaltyPoints}',
                                      style: const TextStyle(fontSize: 13)),
                                ],
                              )),
                              // Actions
                              DataCell(IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 16, color: AppTheme.textSecondary),
                                onPressed: () =>
                                    _showCustomerDialog(context, ref, customer: c),
                              )),
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

  void _showCustomerDialog(BuildContext context, WidgetRef ref,
      {Customer? customer}) {
    final nameCtrl = TextEditingController(text: customer?.name);
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final notifier = ref.read(customersNotifierProvider.notifier);
              if (customer == null) {
                await notifier.addCustomer(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                );
              } else {
                await notifier.updateCustomer(
                  id: customer.id,
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(customer == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
      ),
    );
  }
}
