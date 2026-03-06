import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/features/inventory/providers/inventory_provider.dart';
import 'package:rms_offline/features/menu/providers/menu_provider.dart';
import 'package:rms_offline/widgets/common_widgets.dart';

// ─── Menu Screen ─────────────────────────────────────────────────────────────

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu Items'),
                Tab(icon: Icon(Icons.category), text: 'Categories'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [MenuItemsTab(), CategoriesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu Items Tab ───────────────────────────────────────────────────────────

class MenuItemsTab extends ConsumerWidget {
  const MenuItemsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allMenuItemsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMenuItemForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No menu items yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.fastfood,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cost: \$${item.costPrice.toStringAsFixed(2)} | Sell: \$${item.sellingPrice.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Profit: \$${(item.sellingPrice - item.costPrice).toStringAsFixed(2)} (${((item.sellingPrice - item.costPrice) / item.sellingPrice * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: item.isAvailable,
                        onChanged: (v) => ref
                            .read(menuNotifierProvider.notifier)
                            .updateMenuItem(
                              id: item.id,
                              name: item.name,
                              sellingPrice: item.sellingPrice,
                              costPrice: item.costPrice,
                              isAvailable: v,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showMenuItemForm(context, ref, item: item),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final confirm = await showConfirmDialog(
                            context,
                            title: 'Delete Item',
                            message: 'Delete ${item.name}?',
                            confirmText: 'Delete',
                            confirmColor: Colors.red,
                          );
                          if (confirm) {
                            await ref
                                .read(menuNotifierProvider.notifier)
                                .deleteMenuItem(item.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showMenuItemForm(
    BuildContext context,
    WidgetRef ref, {
    MenuItem? item,
  }) {
    showDialog(
      context: context,
      builder: (_) => MenuItemFormDialog(item: item),
    );
  }
}

// ─── Menu Item Form Dialog ────────────────────────────────────────────────────

class MenuItemFormDialog extends ConsumerStatefulWidget {
  final MenuItem? item;
  const MenuItemFormDialog({super.key, this.item});

  @override
  ConsumerState<MenuItemFormDialog> createState() => _MenuItemFormDialogState();
}

class _MenuItemFormDialogState extends ConsumerState<MenuItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _sellingCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _descCtrl;
  String? _categoryId;
  bool _isAvailable = true;
  bool _isLoading = false;
  final List<Map<String, dynamic>> _selectedIngredients = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _sellingCtrl = TextEditingController(
      text: widget.item?.sellingPrice.toString() ?? '',
    );
    _costCtrl = TextEditingController(
      text: widget.item?.costPrice.toString() ?? '',
    );
    _descCtrl = TextEditingController(text: widget.item?.description ?? '');
    _categoryId = widget.item?.categoryId;
    _isAvailable = widget.item?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sellingCtrl.dispose();
    _costCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (widget.item == null) {
        await ref
            .read(menuNotifierProvider.notifier)
            .addMenuItem(
              name: _nameCtrl.text.trim(),
              sellingPrice: double.parse(_sellingCtrl.text),
              costPrice: double.parse(_costCtrl.text),
              categoryId: _categoryId,
              description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
              ingredients: _selectedIngredients,
            );
      } else {
        await ref
            .read(menuNotifierProvider.notifier)
            .updateMenuItem(
              id: widget.item!.id,
              name: _nameCtrl.text.trim(),
              sellingPrice: double.parse(_sellingCtrl.text),
              costPrice: double.parse(_costCtrl.text),
              categoryId: _categoryId,
              description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
              isAvailable: _isAvailable,
              ingredients: _selectedIngredients,
            );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);

    return AlertDialog(
      title: Text(widget.item == null ? 'Add Menu Item' : 'Edit Menu Item'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cost Price *',
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price *',
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                categoriesAsync.when(
                  data: (cats) => DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No Category'),
                      ),
                      ...cats.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                // Recipe / Ingredients
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recipe Ingredients:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                ingredientsAsync.when(
                  data: (ings) => IngredientSelector(
                    ingredients: ings,
                    selected: _selectedIngredients,
                    onChanged: (list) => setState(() {
                      _selectedIngredients.clear();
                      _selectedIngredients.addAll(list);
                    }),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
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
              : Text(widget.item == null ? 'Add Item' : 'Save Changes'),
        ),
      ],
    );
  }
}

// ─── Ingredient Selector ──────────────────────────────────────────────────────

class IngredientSelector extends StatefulWidget {
  final List<Ingredient> ingredients;
  final List<Map<String, dynamic>> selected;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const IngredientSelector({
    super.key,
    required this.ingredients,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<IngredientSelector> createState() => _IngredientSelectorState();
}

class _IngredientSelectorState extends State<IngredientSelector> {
  late List<Map<String, dynamic>> _list;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.selected);
  }

  void _addIngredient(Ingredient ing) {
    if (_list.any((e) => e['ingredientId'] == ing.id)) return;
    setState(() {
      _list.add({
        'ingredientId': ing.id,
        'name': ing.name,
        'unit': ing.unit,
        'quantity': 1.0,
      });
    });
    widget.onChanged(_list);
  }

  void _removeIngredient(String ingId) {
    setState(() {
      _list.removeWhere((e) => e['ingredientId'] == ingId);
    });
    widget.onChanged(_list);
  }

  void _updateQuantity(String ingId, double qty) {
    final idx = _list.indexWhere((e) => e['ingredientId'] == ingId);
    if (idx >= 0) {
      setState(() {
        _list[idx] = {..._list[idx], 'quantity': qty};
      });
      widget.onChanged(_list);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add ingredient dropdown
        DropdownButtonFormField<Ingredient>(
          decoration: const InputDecoration(
            labelText: 'Add Ingredient',
            isDense: true,
          ),
          initialValue: null,
          items: widget.ingredients
              .where((i) => !_list.any((s) => s['ingredientId'] == i.id))
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text('${i.name} (${i.unit})'),
                ),
              )
              .toList(),
          onChanged: (i) {
            if (i != null) _addIngredient(i);
          },
        ),
        // Selected ingredients list
        if (_list.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._list.map((entry) {
            final ctrl = TextEditingController(
              text: entry['quantity'].toString(),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text('${entry['name']} (${entry['unit']})')),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        suffix: Text(entry['unit'] as String),
                      ),
                      onChanged: (v) => _updateQuantity(
                        entry['ingredientId'] as String,
                        double.tryParse(v) ?? 1.0,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        _removeIngredient(entry['ingredientId'] as String),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─── Categories Tab ───────────────────────────────────────────────────────────

class CategoriesTab extends ConsumerWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCategory(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: categoriesAsync.when(
        data: (cats) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cats.length,
          itemBuilder: (ctx, i) {
            final cat = cats[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.category,
                    color: AppTheme.accentColor,
                  ),
                ),
                title: Text(cat.name),
                subtitle: cat.description != null
                    ? Text(cat.description!)
                    : null,
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _addCategory(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Category Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await ref
                    .read(menuNotifierProvider.notifier)
                    .addCategory(ctrl.text.trim());
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
