import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/restaurant_tables.dart';

part 'restaurant_database.g.dart';

@DriftDatabase(
  tables: [
    RestaurantUsers,
    MenuCategories,
    MenuItems,
    Ingredients,
    MenuItemIngredients,
    StockMovements,
    RestaurantTables,
    Orders,
    OrderItems,
    Customers,
    SyncQueue,
  ],
)
class RestaurantDatabase extends _$RestaurantDatabase {
  final String restaurantId;

  RestaurantDatabase(this.restaurantId)
    : super(_openRestaurantConnection(restaurantId));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(customers);
      }
    },
  );

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<RestaurantUser?> getUserByEmail(String email) {
    return (select(restaurantUsers)
          ..where((u) => u.email.equals(email))
          ..where((u) => u.isActive))
        .getSingleOrNull();
  }

  Future<List<RestaurantUser>> getAllUsers() {
    return (select(
      restaurantUsers,
    )..where((u) => u.syncStatus.isNotValue(2))).get();
  }

  Stream<List<RestaurantUser>> watchAllUsers() {
    return (select(restaurantUsers)
          ..where((u) => u.syncStatus.isNotValue(2))
          ..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .watch();
  }

  Future<void> upsertUser(RestaurantUsersCompanion user) async {
    await into(restaurantUsers).insertOnConflictUpdate(user);
  }

  Future<void> softDeleteUser(String id) async {
    await (update(restaurantUsers)..where((u) => u.id.equals(id))).write(
      RestaurantUsersCompanion(
        syncStatus: const Value(2),
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ─── Menu Categories ───────────────────────────────────────────────────────

  Stream<List<MenuCategory>> watchMenuCategories() {
    return (select(menuCategories)
          ..where((c) => c.isActive)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  Future<List<MenuCategory>> getAllCategories() {
    return (select(menuCategories)..where((c) => c.isActive)).get();
  }

  Future<void> upsertCategory(MenuCategoriesCompanion category) async {
    await into(menuCategories).insertOnConflictUpdate(category);
  }

  // ─── Menu Items ───────────────────────────────────────────────────────────

  Stream<List<MenuItem>> watchMenuItems({String? categoryId}) {
    return (select(menuItems)
          ..where((m) => m.syncStatus.isNotValue(2))
          ..where(
            (m) => categoryId != null
                ? m.categoryId.equals(categoryId)
                : const Constant(true),
          )
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .watch();
  }

  Future<List<MenuItem>> getAllMenuItems() {
    return (select(menuItems)
          ..where((m) => m.syncStatus.isNotValue(2))
          ..where((m) => m.isAvailable))
        .get();
  }

  Future<MenuItem?> getMenuItemById(String id) {
    return (select(menuItems)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertMenuItem(MenuItemsCompanion item) async {
    await into(menuItems).insertOnConflictUpdate(item);
  }

  Future<void> softDeleteMenuItem(String id) async {
    await (update(menuItems)..where((m) => m.id.equals(id))).write(
      MenuItemsCompanion(
        syncStatus: const Value(2),
        isAvailable: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ─── Ingredients ───────────────────────────────────────────────────────────

  Stream<List<Ingredient>> watchIngredients() {
    return (select(ingredients)
          ..where((i) => i.syncStatus.isNotValue(2))
          ..orderBy([(i) => OrderingTerm.asc(i.name)]))
        .watch();
  }

  Future<List<Ingredient>> getAllIngredients() {
    return (select(
      ingredients,
    )..where((i) => i.syncStatus.isNotValue(2))).get();
  }

  Future<Ingredient?> getIngredientById(String id) {
    return (select(
      ingredients,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertIngredient(IngredientsCompanion ingredient) async {
    await into(ingredients).insertOnConflictUpdate(ingredient);
  }

  Future<void> updateIngredientStock(String id, double newQty) async {
    await (update(ingredients)..where((i) => i.id.equals(id))).write(
      IngredientsCompanion(
        stockQuantity: Value(newQty),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Ingredient>> getLowStockIngredients() async {
    final all = await (select(
      ingredients,
    )..where((i) => i.syncStatus.isNotValue(2))).get();
    return all.where((i) => i.stockQuantity <= i.lowStockThreshold).toList();
  }

  // ─── Menu Item Ingredients (recipe) ───────────────────────────────────────

  Future<List<MenuItemIngredient>> getIngredientsForMenuItem(
    String menuItemId,
  ) {
    return (select(
      menuItemIngredients,
    )..where((r) => r.menuItemId.equals(menuItemId))).get();
  }

  Future<void> upsertMenuItemIngredient(
    MenuItemIngredientsCompanion recipe,
  ) async {
    await into(menuItemIngredients).insertOnConflictUpdate(recipe);
  }

  Future<void> deleteMenuItemIngredients(String menuItemId) async {
    await (delete(
      menuItemIngredients,
    )..where((r) => r.menuItemId.equals(menuItemId))).go();
  }

  // ─── Tables ───────────────────────────────────────────────────────────────

  Stream<List<RestaurantTable>> watchTables() {
    return (select(restaurantTables)
          ..where((t) => t.syncStatus.isNotValue(2))
          ..orderBy([(t) => OrderingTerm.asc(t.tableLabel)]))
        .watch();
  }

  Future<List<RestaurantTable>> getAllTables() {
    return (select(
      restaurantTables,
    )..where((t) => t.syncStatus.isNotValue(2))).get();
  }

  Future<void> upsertTable(RestaurantTablesCompanion table) async {
    await into(restaurantTables).insertOnConflictUpdate(table);
  }

  Future<void> updateTableStatus(
    String id,
    String status,
    String? currentOrderId,
  ) async {
    await (update(restaurantTables)..where((t) => t.id.equals(id))).write(
      RestaurantTablesCompanion(
        status: Value(status),
        currentOrderId: Value(currentOrderId),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ─── Orders ───────────────────────────────────────────────────────────────

  Stream<List<Order>> watchActiveOrders() {
    return (select(orders)
          ..where((o) => o.status.isNotValue('cancelled'))
          ..where((o) => o.status.isNotValue('served'))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Stream<List<Order>> watchOrdersByStatus(String status) {
    return (select(orders)
          ..where((o) => o.status.equals(status))
          ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
        .watch();
  }

  Future<List<Order>> getOrdersForTable(String tableId) {
    return (select(orders)
          ..where((o) => o.tableId.equals(tableId))
          ..where((o) => o.status.isNotValue('cancelled'))
          ..where((o) => o.status.isNotValue('served'))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .get();
  }

  Future<Order?> getOrderById(String id) {
    return (select(orders)..where((o) => o.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertOrder(OrdersCompanion order) async {
    await into(orders).insertOnConflictUpdate(order);
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await (update(orders)..where((o) => o.id.equals(id))).write(
      OrdersCompanion(
        status: Value(status),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateOrderPayment(
    String id,
    String paymentStatus,
    String paymentMethod,
    double paidAmount,
  ) async {
    await (update(orders)..where((o) => o.id.equals(id))).write(
      OrdersCompanion(
        paymentStatus: Value(paymentStatus),
        paymentMethod: Value(paymentMethod),
        paidAmount: Value(paidAmount),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Order>> getTodayOrders() async {
    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final all = await (select(
      orders,
    )..orderBy([(o) => OrderingTerm.desc(o.createdAt)])).get();
    return all.where((o) => !o.createdAt.isBefore(startOfDay)).toList();
  }

  // ─── Order Items ───────────────────────────────────────────────────────────

  Stream<List<OrderItem>> watchOrderItems(String orderId) {
    return (select(
      orderItems,
    )..where((oi) => oi.orderId.equals(orderId))).watch();
  }

  Future<List<OrderItem>> getOrderItems(String orderId) {
    return (select(
      orderItems,
    )..where((oi) => oi.orderId.equals(orderId))).get();
  }

  Future<void> upsertOrderItem(OrderItemsCompanion item) async {
    await into(orderItems).insertOnConflictUpdate(item);
  }

  Future<void> updateOrderItemStatus(String id, String status) async {
    await (update(orderItems)..where((oi) => oi.id.equals(id))).write(
      OrderItemsCompanion(
        status: Value(status),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteOrderItem(String id) async {
    await (delete(orderItems)..where((oi) => oi.id.equals(id))).go();
  }

  // ─── Stock Movements ───────────────────────────────────────────────────────

  Future<void> insertStockMovement(StockMovementsCompanion movement) async {
    await into(stockMovements).insert(movement);
  }

  Future<List<StockMovement>> getMovementsForIngredient(String ingredientId) {
    return (select(stockMovements)
          ..where((m) => m.ingredientId.equals(ingredientId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  // ─── Sync Queue ───────────────────────────────────────────────────────────

  // ─── Customers ────────────────────────────────────────────────────────────

  Stream<List<Customer>> watchAllCustomers() {
    return (select(customers)
          ..where((c) => c.restaurantId.equals(restaurantId))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<List<Customer>> getAllCustomers() {
    return (select(customers)
          ..where((c) => c.restaurantId.equals(restaurantId))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Future<void> upsertCustomer(CustomersCompanion customer) async {
    await into(customers).insertOnConflictUpdate(customer);
  }

  Future<void> deleteCustomer(String id) async {
    await (delete(customers)..where((c) => c.id.equals(id))).go();
  }

  // ─── Sync Queue ───────────────────────────────────────────────────────────

  Future<void> addToSyncQueue({
    required String id,
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await into(syncQueue).insertOnConflictUpdate(
      SyncQueueCompanion.insert(
        id: id,
        entityTable: tableName,
        recordId: recordId,
        operation: operation,
        payload: jsonEncode(payload),
      ),
    );
  }

  Future<List<SyncQueueData>> getPendingSyncItems() {
    return (select(syncQueue)
          ..where((s) => s.processedAt.isNull())
          ..where((s) => s.retryCount.isSmallerThanValue(3))
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
        .get();
  }

  Future<void> markSyncItemProcessed(String id) async {
    await (update(syncQueue)..where((s) => s.id.equals(id))).write(
      SyncQueueCompanion(processedAt: Value(DateTime.now())),
    );
  }

  Future<void> incrementSyncRetry(String id, String error) async {
    final item = await (select(
      syncQueue,
    )..where((s) => s.id.equals(id))).getSingle();
    await (update(syncQueue)..where((s) => s.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(item.retryCount + 1),
        errorMessage: Value(error),
      ),
    );
  }

  Future<void> clearProcessedSyncItems() async {
    await (delete(syncQueue)..where((s) => s.processedAt.isNotNull())).go();
  }

  // ─── Dashboard stats ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final todayOrders = await getTodayOrders();
    final paidOrders = todayOrders
        .where((o) => o.paymentStatus == 'paid')
        .toList();
    final lowStock = await getLowStockIngredients();

    double totalRevenue = 0;
    for (final o in paidOrders) {
      totalRevenue += o.totalAmount;
    }

    return {
      'todayOrders': todayOrders.length,
      'todayRevenue': totalRevenue,
      'pendingOrders': todayOrders.where((o) => o.status == 'pending').length,
      'preparingOrders': todayOrders
          .where((o) => o.status == 'preparing')
          .length,
      'lowStockCount': lowStock.length,
    };
  }

  // ─── Deduct ingredients when order served ─────────────────────────────────

  Future<void> deductIngredientsForOrder(String orderId) async {
    final items = await getOrderItems(orderId);
    for (final item in items) {
      final recipes = await getIngredientsForMenuItem(item.menuItemId);
      for (final recipe in recipes) {
        final ingredient = await getIngredientById(recipe.ingredientId);
        if (ingredient != null) {
          final needed = recipe.quantityRequired * item.quantity;
          final newQty = (ingredient.stockQuantity - needed).clamp(
            0.0,
            double.infinity,
          );
          await updateIngredientStock(recipe.ingredientId, newQty);
          await insertStockMovement(
            StockMovementsCompanion.insert(
              id: '${orderId}_${recipe.ingredientId}_${DateTime.now().millisecondsSinceEpoch}',
              restaurantId: restaurantId,
              ingredientId: recipe.ingredientId,
              quantity: -needed,
              reason: 'sale',
              referenceId: Value(orderId),
            ),
          );
        }
      }
    }
  }
}

LazyDatabase _openRestaurantConnection(String restaurantId) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final appDir = Directory(
      p.join(dbFolder.path, 'rms_offline', 'restaurants'),
    );
    await appDir.create(recursive: true);
    final file = File(p.join(appDir.path, 'restaurant_$restaurantId.db'));
    return NativeDatabase.createInBackground(file);
  });
}
