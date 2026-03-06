import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/features/inventory/providers/inventory_provider.dart';

// ─── Inventory Screen ─────────────────────────────────────────────────────────

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final lowStockAsync = ref.watch(lowStockProvider);

    return Scaffold(
      body: Column(
        children: [
          // Low stock banner
          lowStockAsync.when(
            data: (lowStock) => lowStock.isNotEmpty
                ? Container(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${lowStock.length} ingredient(s) are low on stock: ${lowStock.take(3).map((i) => i.name).join(', ')}${lowStock.length > 3 ? '...' : ''}',
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: ingredientsAsync.when(
              data: (ingredients) =>
                  _IngredientListView(ingredients: ingredients),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIngredientDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Ingredient'),
      ),
    );
  }

  void _showAddIngredientDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => const IngredientFormDialog());
  }
}

class _IngredientListView extends ConsumerWidget {
  final List<Ingredient> ingredients;
  const _IngredientListView({required this.ingredients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ingredients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No ingredients yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ingredients.length,
      itemBuilder: (ctx, i) {
        final ing = ingredients[i];
        final isLow = ing.stockQuantity <= ing.lowStockThreshold;
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 8,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isLow ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ing.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${ing.stockQuantity.toStringAsFixed(2)} ${ing.unit}',
                            style: TextStyle(
                              color: isLow ? AppTheme.errorColor : Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            ' / min: ${ing.lowStockThreshold.toStringAsFixed(1)} ${ing.unit}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Cost: \$${ing.costPerUnit.toStringAsFixed(2)}/${ing.unit}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Stock level bar
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isLow ? 'LOW STOCK' : 'OK',
                        style: TextStyle(
                          color: isLow
                              ? AppTheme.errorColor
                              : AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (ing.stockQuantity / (ing.lowStockThreshold * 3))
                            .clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: isLow
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Actions
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'adjust') {
                      _showAdjustStockDialog(context, ref, ing);
                    } else if (action == 'edit') {
                      showDialog(
                        context: context,
                        builder: (_) => IngredientFormDialog(ingredient: ing),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'adjust', child: Text('Adjust Stock')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdjustStockDialog(
    BuildContext context,
    WidgetRef ref,
    Ingredient ing,
  ) {
    final ctrl = TextEditingController();
    String reason = 'purchase';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Adjust Stock — ${ing.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current: ${ing.stockQuantity.toStringAsFixed(2)} ${ing.unit}',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Adjustment (+ or -)',
                  suffix: Text(ing.unit),
                  helperText: 'Use negative to deduct stock',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(value: 'purchase', child: Text('Purchase')),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('Manual Adjustment'),
                  ),
                  DropdownMenuItem(
                    value: 'waste',
                    child: Text('Waste/Spoilage'),
                  ),
                  DropdownMenuItem(value: 'return', child: Text('Return')),
                ],
                onChanged: (v) => setState(() => reason = v ?? reason),
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
                final qty = double.tryParse(ctrl.text);
                if (qty == null) return;
                await ref
                    .read(inventoryNotifierProvider.notifier)
                    .adjustStock(
                      ingredientId: ing.id,
                      adjustmentQty: qty,
                      reason: reason,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ingredient Form Dialog ───────────────────────────────────────────────────

class IngredientFormDialog extends ConsumerStatefulWidget {
  final Ingredient? ingredient;
  const IngredientFormDialog({super.key, this.ingredient});

  @override
  ConsumerState<IngredientFormDialog> createState() =>
      _IngredientFormDialogState();
}

class _IngredientFormDialogState extends ConsumerState<IngredientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _thresholdCtrl;
  late TextEditingController _costCtrl;
  String _unit = 'kg';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.ingredient?.name ?? '');
    _stockCtrl = TextEditingController(
      text: widget.ingredient?.stockQuantity.toString() ?? '0',
    );
    _thresholdCtrl = TextEditingController(
      text: widget.ingredient?.lowStockThreshold.toString() ?? '5',
    );
    _costCtrl = TextEditingController(
      text: widget.ingredient?.costPerUnit.toString() ?? '0',
    );
    _unit = widget.ingredient?.unit ?? 'kg';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (widget.ingredient == null) {
        await ref
            .read(inventoryNotifierProvider.notifier)
            .addIngredient(
              name: _nameCtrl.text.trim(),
              unit: _unit,
              stockQuantity: double.parse(_stockCtrl.text),
              lowStockThreshold: double.parse(_thresholdCtrl.text),
              costPerUnit: double.parse(_costCtrl.text),
            );
      } else {
        await ref
            .read(inventoryNotifierProvider.notifier)
            .updateIngredient(
              id: widget.ingredient!.id,
              name: _nameCtrl.text.trim(),
              unit: _unit,
              lowStockThreshold: double.parse(_thresholdCtrl.text),
              costPerUnit: double.parse(_costCtrl.text),
            );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.ingredient == null ? 'Add Ingredient' : 'Edit Ingredient',
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const [
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'L', child: Text('L')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                        DropdownMenuItem(value: 'box', child: Text('box')),
                      ],
                      onChanged: (v) => setState(() => _unit = v ?? _unit),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Cost per $_unit',
                        prefixText: '\$',
                      ),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.ingredient == null)
                TextFormField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Initial Stock Quantity',
                  ),
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Invalid' : null,
                ),
              if (widget.ingredient == null) const SizedBox(height: 12),
              TextFormField(
                controller: _thresholdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Low Stock Threshold',
                ),
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Invalid' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.ingredient == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
