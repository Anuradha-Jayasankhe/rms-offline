import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/restaurant_database.dart';

// ─── Menu Categories ─────────────────────────────────────────────────────────

final menuCategoriesProvider = StreamProvider<List<MenuCategory>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchMenuCategories();
});

// ─── Menu Items ───────────────────────────────────────────────────────────────

final menuItemsProvider = StreamProvider.family<List<MenuItem>, String?>((
  ref,
  categoryId,
) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchMenuItems(categoryId: categoryId);
});

final allMenuItemsProvider = StreamProvider<List<MenuItem>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchMenuItems();
});

// ─── Menu Notifier ────────────────────────────────────────────────────────────

class MenuNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  MenuNotifier(this._ref) : super(const AsyncValue.data(null));

  RestaurantDatabase? get _db => _ref.read(restaurantDatabaseProvider);
  String get _restaurantId => _ref.read(currentRestaurantIdProvider) ?? '';

  Future<void> addCategory(String name, {String? description}) async {
    final db = _db;
    if (db == null) return;
    await db.upsertCategory(
      MenuCategoriesCompanion.insert(
        id: generateId(),
        restaurantId: _restaurantId,
        name: name,
        description: Value(description),
        syncStatus: const Value(1),
      ),
    );
  }

  Future<void> addMenuItem({
    required String name,
    required double sellingPrice,
    required double costPrice,
    String? categoryId,
    String? description,
    List<Map<String, dynamic>> ingredients = const [],
  }) async {
    final db = _db;
    if (db == null) return;
    state = const AsyncValue.loading();
    try {
      final itemId = generateId();
      await db.upsertMenuItem(
        MenuItemsCompanion.insert(
          id: itemId,
          restaurantId: _restaurantId,
          name: name,
          sellingPrice: sellingPrice,
          costPrice: Value(costPrice),
          categoryId: Value(categoryId),
          description: Value(description),
          syncStatus: const Value(1),
          version: const Value(1),
        ),
      );

      // Save recipe (ingredients)
      await db.deleteMenuItemIngredients(itemId);
      for (final ing in ingredients) {
        await db.upsertMenuItemIngredient(
          MenuItemIngredientsCompanion.insert(
            id: generateId(),
            menuItemId: itemId,
            ingredientId: ing['ingredientId'] as String,
            quantityRequired: (ing['quantity'] as num).toDouble(),
            syncStatus: const Value(1),
          ),
        );
      }

      // Add to sync queue
      await db.addToSyncQueue(
        id: generateId(),
        tableName: 'menu_items',
        recordId: itemId,
        operation: 'insert',
        payload: {
          'id': itemId,
          'restaurantId': _restaurantId,
          'name': name,
          'sellingPrice': sellingPrice,
          'costPrice': costPrice,
          'categoryId': categoryId,
        },
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateMenuItem({
    required String id,
    required String name,
    required double sellingPrice,
    required double costPrice,
    String? categoryId,
    String? description,
    bool isAvailable = true,
    List<Map<String, dynamic>> ingredients = const [],
  }) async {
    final db = _db;
    if (db == null) return;
    await db.upsertMenuItem(
      MenuItemsCompanion(
        id: Value(id),
        restaurantId: Value(_restaurantId),
        name: Value(name),
        sellingPrice: Value(sellingPrice),
        costPrice: Value(costPrice),
        categoryId: Value(categoryId),
        description: Value(description),
        isAvailable: Value(isAvailable),
        syncStatus: const Value(1),
        version: const Value(2),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Update recipe
    await db.deleteMenuItemIngredients(id);
    for (final ing in ingredients) {
      await db.upsertMenuItemIngredient(
        MenuItemIngredientsCompanion.insert(
          id: generateId(),
          menuItemId: id,
          ingredientId: ing['ingredientId'] as String,
          quantityRequired: (ing['quantity'] as num).toDouble(),
          syncStatus: const Value(1),
        ),
      );
    }

    await db.addToSyncQueue(
      id: generateId(),
      tableName: 'menu_items',
      recordId: id,
      operation: 'update',
      payload: {'id': id, 'name': name, 'sellingPrice': sellingPrice},
    );
  }

  Future<void> deleteMenuItem(String id) async {
    final db = _db;
    if (db == null) return;
    await db.softDeleteMenuItem(id);
    await db.addToSyncQueue(
      id: generateId(),
      tableName: 'menu_items',
      recordId: id,
      operation: 'delete',
      payload: {'id': id},
    );
  }

  Future<List<MenuItemIngredient>> getItemIngredients(String menuItemId) async {
    return _db?.getIngredientsForMenuItem(menuItemId) ?? [];
  }
}

final menuNotifierProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<void>>(
      (ref) => MenuNotifier(ref),
    );
