import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/restaurant_database.dart';

// ─── Kitchen Streams ─────────────────────────────────────────────────────────

final kitchenOrdersProvider = StreamProvider<List<Order>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  // Show pending and preparing orders
  return db.watchActiveOrders();
});

final pendingOrdersProvider = StreamProvider<List<Order>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchOrdersByStatus('pending');
});

final preparingOrdersProvider = StreamProvider<List<Order>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchOrdersByStatus('preparing');
});

final readyOrdersProvider = StreamProvider<List<Order>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchOrdersByStatus('ready');
});

// ─── Kitchen Notifier ─────────────────────────────────────────────────────────

class KitchenNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  KitchenNotifier(this._ref) : super(const AsyncValue.data(null));

  RestaurantDatabase? get _db => _ref.read(restaurantDatabaseProvider);

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final db = _db;
    if (db == null) return;
    await db.updateOrderStatus(orderId, newStatus);
    await db.addToSyncQueue(
      id: generateId(),
      tableName: 'orders',
      recordId: orderId,
      operation: 'update',
      payload: {'id': orderId, 'status': newStatus},
    );
  }

  Future<void> updateItemStatus(String itemId, String newStatus) async {
    final db = _db;
    if (db == null) return;
    await db.updateOrderItemStatus(itemId, newStatus);
  }

  Future<void> markOrderPreparing(String orderId) =>
      updateOrderStatus(orderId, 'preparing');

  Future<void> markOrderReady(String orderId) =>
      updateOrderStatus(orderId, 'ready');

  Future<void> markOrderServed(String orderId) async {
    await updateOrderStatus(orderId, 'served');
    // Deduct ingredients
    final db = _db;
    if (db != null) {
      await db.deductIngredientsForOrder(orderId);
    }
  }
}

final kitchenNotifierProvider =
    StateNotifierProvider<KitchenNotifier, AsyncValue<void>>(
      (ref) => KitchenNotifier(ref),
    );

final kitchenOrderItemsProvider =
    StreamProvider.family<List<OrderItem>, String>((ref, orderId) {
      final db = ref.watch(restaurantDatabaseProvider);
      if (db == null) return const Stream.empty();
      return db.watchOrderItems(orderId);
    });
