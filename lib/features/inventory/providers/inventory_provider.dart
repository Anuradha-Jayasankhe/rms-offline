import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/restaurant_database.dart';

// ─── Streams ─────────────────────────────────────────────────────────────────

final ingredientsProvider = StreamProvider<List<Ingredient>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchIngredients();
});

final lowStockProvider = FutureProvider<List<Ingredient>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return Future.value([]);
  return db.getLowStockIngredients();
});

// ─── Inventory Notifier ───────────────────────────────────────────────────────

class InventoryNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  InventoryNotifier(this._ref) : super(const AsyncValue.data(null));

  RestaurantDatabase? get _db => _ref.read(restaurantDatabaseProvider);
  String get _restaurantId => _ref.read(currentRestaurantIdProvider) ?? '';

  Future<void> addIngredient({
    required String name,
    required String unit,
    required double stockQuantity,
    required double lowStockThreshold,
    required double costPerUnit,
  }) async {
    final db = _db;
    if (db == null) return;
    final id = generateId();
    await db.upsertIngredient(
      IngredientsCompanion.insert(
        id: id,
        restaurantId: _restaurantId,
        name: name,
        unit: unit,
        stockQuantity: Value(stockQuantity),
        lowStockThreshold: Value(lowStockThreshold),
        costPerUnit: Value(costPerUnit),
        syncStatus: const Value(1),
      ),
    );
    await db.addToSyncQueue(
      id: generateId(),
      tableName: 'ingredients',
      recordId: id,
      operation: 'insert',
      payload: {
        'id': id,
        'restaurantId': _restaurantId,
        'name': name,
        'unit': unit,
        'stockQuantity': stockQuantity,
        'costPerUnit': costPerUnit,
      },
    );
  }

  Future<void> updateIngredient({
    required String id,
    required String name,
    required String unit,
    required double lowStockThreshold,
    required double costPerUnit,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.upsertIngredient(
      IngredientsCompanion(
        id: Value(id),
        restaurantId: Value(_restaurantId),
        name: Value(name),
        unit: Value(unit),
        lowStockThreshold: Value(lowStockThreshold),
        costPerUnit: Value(costPerUnit),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> adjustStock({
    required String ingredientId,
    required double adjustmentQty,
    required String reason,
  }) async {
    final db = _db;
    if (db == null) return;
    final ingredient = await db.getIngredientById(ingredientId);
    if (ingredient == null) return;

    final newQty = (ingredient.stockQuantity + adjustmentQty).clamp(
      0.0,
      double.infinity,
    );
    await db.updateIngredientStock(ingredientId, newQty);
    await db.insertStockMovement(
      StockMovementsCompanion.insert(
        id: generateId(),
        restaurantId: _restaurantId,
        ingredientId: ingredientId,
        quantity: adjustmentQty,
        reason: reason,
        syncStatus: const Value(1),
      ),
    );
    await db.addToSyncQueue(
      id: generateId(),
      tableName: 'ingredients',
      recordId: ingredientId,
      operation: 'update',
      payload: {'id': ingredientId, 'stockQuantity': newQty},
    );
  }
}

final inventoryNotifierProvider =
    StateNotifierProvider<InventoryNotifier, AsyncValue<void>>(
      (ref) => InventoryNotifier(ref),
    );
