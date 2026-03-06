import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'restaurant_database.dart';

/// Manages the lifecycle of all databases.
/// AppDatabase is a singleton; RestaurantDatabase is per-restaurant.
class DatabaseManager {
  DatabaseManager._internal();
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;

  AppDatabase? _appDatabase;
  final Map<String, RestaurantDatabase> _restaurantDbs = {};

  AppDatabase get appDatabase {
    _appDatabase ??= AppDatabase();
    return _appDatabase!;
  }

  /// Returns (or creates) the database for a specific restaurant.
  /// Each restaurant has its own isolated .db file.
  RestaurantDatabase getRestaurantDatabase(String restaurantId) {
    if (!_restaurantDbs.containsKey(restaurantId)) {
      _restaurantDbs[restaurantId] = RestaurantDatabase(restaurantId);
    }
    return _restaurantDbs[restaurantId]!;
  }

  /// Close a specific restaurant database (e.g., when logging out)
  Future<void> closeRestaurantDatabase(String restaurantId) async {
    final db = _restaurantDbs.remove(restaurantId);
    await db?.close();
  }

  Future<void> closeAll() async {
    await _appDatabase?.close();
    for (final db in _restaurantDbs.values) {
      await db.close();
    }
    _restaurantDbs.clear();
    _appDatabase = null;
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final databaseManagerProvider = Provider<DatabaseManager>((ref) {
  final manager = DatabaseManager();
  ref.onDispose(() => manager.closeAll());
  return manager;
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return ref.watch(databaseManagerProvider).appDatabase;
});

/// The currently active restaurant's database.
/// Must be set after login / restaurant selection.
final currentRestaurantIdProvider = StateProvider<String?>((ref) => null);

final restaurantDatabaseProvider = Provider<RestaurantDatabase?>((ref) {
  final restaurantId = ref.watch(currentRestaurantIdProvider);
  if (restaurantId == null) return null;
  return ref.watch(databaseManagerProvider).getRestaurantDatabase(restaurantId);
});
