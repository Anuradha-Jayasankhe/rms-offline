import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/restaurant_database.dart';

// ─── Cart Item (in-memory, not persisted until order is created) ─────────────

class CartItem {
  final String menuItemId;
  final String menuItemName;
  final double unitPrice;
  int quantity;
  String? notes;

  CartItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.unitPrice,
    this.quantity = 1,
    this.notes,
  });

  double get subtotal => unitPrice * quantity;

  CartItem copyWith({int? quantity, String? notes}) {
    return CartItem(
      menuItemId: menuItemId,
      menuItemName: menuItemName,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }
}

// ─── POS State ────────────────────────────────────────────────────────────────

class PosState {
  final List<CartItem> cartItems;
  final String? selectedTableId;
  final String? selectedTableName;
  final String? activeOrderId;
  final bool isLoading;
  final String? error;

  const PosState({
    this.cartItems = const [],
    this.selectedTableId,
    this.selectedTableName,
    this.activeOrderId,
    this.isLoading = false,
    this.error,
  });

  double get subtotal => cartItems.fold(0, (sum, item) => sum + item.subtotal);
  double get taxAmount => subtotal * 0.1; // 10% tax
  double get totalAmount => subtotal + taxAmount;
  int get itemCount => cartItems.fold(0, (sum, item) => sum + item.quantity);

  PosState copyWith({
    List<CartItem>? cartItems,
    String? selectedTableId,
    String? selectedTableName,
    String? activeOrderId,
    bool? isLoading,
    String? error,
  }) {
    return PosState(
      cartItems: cartItems ?? this.cartItems,
      selectedTableId: selectedTableId ?? this.selectedTableId,
      selectedTableName: selectedTableName ?? this.selectedTableName,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── POS Notifier ─────────────────────────────────────────────────────────────

class PosNotifier extends StateNotifier<PosState> {
  final Ref _ref;
  PosNotifier(this._ref) : super(const PosState());

  RestaurantDatabase? get _db => _ref.read(restaurantDatabaseProvider);
  String get _restaurantId => _ref.read(currentRestaurantIdProvider) ?? '';

  void selectTable(String tableId, String tableName) {
    state = state.copyWith(
      selectedTableId: tableId,
      selectedTableName: tableName,
      cartItems: [],
      activeOrderId: null,
    );
  }

  void addToCart(MenuItem item) {
    final existingIdx = state.cartItems.indexWhere(
      (c) => c.menuItemId == item.id,
    );
    if (existingIdx >= 0) {
      final updated = List<CartItem>.from(state.cartItems);
      updated[existingIdx] = updated[existingIdx].copyWith(
        quantity: updated[existingIdx].quantity + 1,
      );
      state = state.copyWith(cartItems: updated);
    } else {
      state = state.copyWith(
        cartItems: [
          ...state.cartItems,
          CartItem(
            menuItemId: item.id,
            menuItemName: item.name,
            unitPrice: item.sellingPrice,
          ),
        ],
      );
    }
  }

  void removeFromCart(String menuItemId) {
    state = state.copyWith(
      cartItems: state.cartItems
          .where((c) => c.menuItemId != menuItemId)
          .toList(),
    );
  }

  void updateCartItemQty(String menuItemId, int qty) {
    if (qty <= 0) {
      removeFromCart(menuItemId);
      return;
    }
    final updated = state.cartItems.map((c) {
      if (c.menuItemId == menuItemId) return c.copyWith(quantity: qty);
      return c;
    }).toList();
    state = state.copyWith(cartItems: updated);
  }

  void clearCart() {
    state = const PosState();
  }

  Future<String?> createOrder({String? notes}) async {
    final db = _db;
    if (db == null || state.cartItems.isEmpty) return null;

    state = state.copyWith(isLoading: true);
    try {
      final orderId = generateId();
      final now = DateTime.now();

      // Create order
      await db.upsertOrder(
        OrdersCompanion.insert(
          id: orderId,
          restaurantId: _restaurantId,
          tableId: Value(state.selectedTableId),
          tableLabel: Value(state.selectedTableName),
          subtotal: Value(state.subtotal),
          taxAmount: Value(state.taxAmount),
          totalAmount: Value(state.totalAmount),
          notes: Value(notes),
          status: const Value('pending'),
          syncStatus: const Value(1),
          version: const Value(1),
        ),
      );

      // Create order items
      for (final cartItem in state.cartItems) {
        await db.upsertOrderItem(
          OrderItemsCompanion.insert(
            id: generateId(),
            orderId: orderId,
            menuItemId: cartItem.menuItemId,
            menuItemName: cartItem.menuItemName,
            unitPrice: cartItem.unitPrice,
            quantity: Value(cartItem.quantity),
            subtotal: cartItem.subtotal,
            notes: Value(cartItem.notes),
            status: const Value('pending'),
            syncStatus: const Value(1),
          ),
        );
      }

      // Update table status
      if (state.selectedTableId != null) {
        await db.updateTableStatus(state.selectedTableId!, 'occupied', orderId);
      }

      // Add to sync queue
      await db.addToSyncQueue(
        id: generateId(),
        tableName: 'orders',
        recordId: orderId,
        operation: 'insert',
        payload: {
          'id': orderId,
          'restaurantId': _restaurantId,
          'tableId': state.selectedTableId,
          'totalAmount': state.totalAmount,
          'status': 'pending',
        },
      );

      state = state.copyWith(
        isLoading: false,
        activeOrderId: orderId,
        cartItems: [],
      );
      return orderId;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> processPayment({
    required String orderId,
    required String paymentMethod,
    required double paidAmount,
  }) async {
    final db = _db;
    if (db == null) return;

    await db.updateOrderPayment(orderId, 'paid', paymentMethod, paidAmount);
    await db.updateOrderStatus(orderId, 'served');

    // Deduct ingredients from inventory
    await db.deductIngredientsForOrder(orderId);

    // Free the table
    if (state.selectedTableId != null) {
      await db.updateTableStatus(state.selectedTableId!, 'available', null);
    }

    await db.addToSyncQueue(
      id: generateId(),
      tableName: 'orders',
      recordId: orderId,
      operation: 'update',
      payload: {
        'id': orderId,
        'paymentStatus': 'paid',
        'paymentMethod': paymentMethod,
        'paidAmount': paidAmount,
        'status': 'served',
      },
    );

    clearCart();
  }
}

// ─── Table Streams ────────────────────────────────────────────────────────────

final tablesProvider = StreamProvider<List<RestaurantTable>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchTables();
});

final activeOrdersProvider = StreamProvider<List<Order>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchActiveOrders();
});

final orderItemsProvider = StreamProvider.family<List<OrderItem>, String>((
  ref,
  orderId,
) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchOrderItems(orderId);
});

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return Future.value({});
  return db.getDashboardStats();
});

final posNotifierProvider = StateNotifierProvider<PosNotifier, PosState>(
  (ref) => PosNotifier(ref),
);
