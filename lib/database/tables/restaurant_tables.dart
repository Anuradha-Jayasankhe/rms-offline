import 'package:drift/drift.dart';

// ─── Per-restaurant tables (in restaurant_{id}.db) ───────────────────────────

/// Staff / users of the restaurant
class RestaurantUsers extends Table {
  TextColumn get id => text()();
  TextColumn get restaurantId => text()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  TextColumn get passwordHash => text()();
  TextColumn get role => text()(); // owner | staff | kitchen | cashier
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Menu categories
class MenuCategories extends Table {
  TextColumn get id => text()();
  TextColumn get restaurantId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Menu items
class MenuItems extends Table {
  TextColumn get id => text()();
  TextColumn get restaurantId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellingPrice => real()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ingredients / raw materials
class Ingredients extends Table {
  TextColumn get id => text()();
  TextColumn get restaurantId => text()();
  TextColumn get name => text()();
  TextColumn get unit => text()(); // kg, g, L, ml, pcs
  RealColumn get stockQuantity => real().withDefault(const Constant(0.0))();
  RealColumn get lowStockThreshold => real().withDefault(const Constant(5.0))();
  RealColumn get costPerUnit => real().withDefault(const Constant(0.0))();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Recipe: which ingredients a menu item uses
class MenuItemIngredients extends Table {
  TextColumn get id => text()();
  TextColumn get menuItemId => text()();
  TextColumn get ingredientId => text()();
  RealColumn get quantityRequired => real()();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Inventory stock adjustments log
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get restaurantId => text()();
  TextColumn get ingredientId => text()();
  RealColumn get quantity => real()(); // positive = in, negative = out
  TextColumn get reason => text()(); // purchase | sale | manual | waste
  TextColumn get referenceId => text().nullable()(); // orderId if from sale
  TextColumn get createdBy => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Restaurant tables (seating tables)
class RestaurantTables extends Table {
  TextColumn get id => text()();
  TextColumn get restaurantId => text()();
  TextColumn get tableLabel => text()(); // Table 1, A1, etc.
  IntColumn get capacity => integer().withDefault(const Constant(4))();
  TextColumn get status => text().withDefault(
    const Constant('available'),
  )(); // available|occupied|reserved
  TextColumn get currentOrderId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Orders
class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get restaurantId => text()();
  TextColumn get tableId => text().nullable()();
  TextColumn get tableLabel => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending|preparing|ready|served|cancelled
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('unpaid'))(); // unpaid|paid|partial
  TextColumn get paymentMethod => text().nullable()(); // cash|card|online
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Order line items
class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get menuItemId => text()();
  TextColumn get menuItemName => text()();
  RealColumn get unitPrice => real()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get subtotal => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending|preparing|ready
  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync queue - operations waiting to sync to server
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityTable => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // insert | update | delete
  TextColumn get payload => text()(); // JSON string
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get processedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
