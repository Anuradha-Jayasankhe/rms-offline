import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/app_database.dart';
import 'package:rms_offline/database/tables/app_tables.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/database/tables/restaurant_tables.dart';

// ─── Platform Admin Provider ─────────────────────────────────────────────────

class PlatformAdminNotifier
    extends StateNotifier<AsyncValue<List<Restaurant>>> {
  final Ref _ref;

  PlatformAdminNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadRestaurants();
  }

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> loadRestaurants() async {
    try {
      final restaurants = await _db.getAllRestaurants();
      state = AsyncValue.data(restaurants);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new restaurant AND initializes its own database with an owner account
  Future<void> createRestaurant({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String ownerName,
    required String ownerEmail,
    required String ownerPassword,
    String subscriptionPlan = 'basic',
  }) async {
    final restaurantId = generateId();
    final ownerId = generateId();

    // 1. Create the restaurant record in the app DB
    await _db.upsertRestaurant(
      RestaurantsCompanion.insert(
        id: restaurantId,
        name: name,
        address: Value(address),
        phone: Value(phone),
        email: Value(email),
        ownerId: Value(ownerId),
        subscriptionPlan: Value(subscriptionPlan),
        syncStatus: const Value(1),
        version: const Value(1),
      ),
    );

    // 2. Open (create) the restaurant's own isolated SQLite database
    final manager = _ref.read(databaseManagerProvider);
    final restaurantDb = manager.getRestaurantDatabase(restaurantId);

    // 3. Seed the owner account in that restaurant's DB
    await restaurantDb.upsertUser(
      RestaurantUsersCompanion.insert(
        id: ownerId,
        restaurantId: restaurantId,
        name: ownerName,
        email: ownerEmail,
        passwordHash: _hashPassword(ownerPassword),
        role: 'owner',
        syncStatus: const Value(1),
      ),
    );

    // 4. Seed default tables
    for (var i = 1; i <= 10; i++) {
      await restaurantDb.upsertTable(
        RestaurantTablesCompanion.insert(
          id: generateId(),
          restaurantId: restaurantId,
          tableLabel: 'Table $i',
          capacity: const Value(4),
        ),
      );
    }

    await loadRestaurants();
  }

  Future<void> updateRestaurant({
    required String id,
    required String name,
    required String address,
    required String phone,
  }) async {
    await _db.upsertRestaurant(
      RestaurantsCompanion(
        id: Value(id),
        name: Value(name),
        address: Value(address),
        phone: Value(phone),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await loadRestaurants();
  }

  Future<void> toggleRestaurantStatus(String id, bool isActive) async {
    await _db.upsertRestaurant(
      RestaurantsCompanion(
        id: Value(id),
        isActive: Value(isActive),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await loadRestaurants();
  }

  Future<void> deleteRestaurant(String id) async {
    await _db.softDeleteRestaurant(id);
    await loadRestaurants();
  }
}

final platformAdminProvider =
    StateNotifierProvider<PlatformAdminNotifier, AsyncValue<List<Restaurant>>>(
      (ref) => PlatformAdminNotifier(ref),
    );

final restaurantStreamProvider = StreamProvider<List<Restaurant>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllRestaurants();
});

// ─── Restaurant Stats ─────────────────────────────────────────────────────────

final restaurantStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((
      ref,
      restaurantId,
    ) async {
      final manager = ref.watch(databaseManagerProvider);
      final db = manager.getRestaurantDatabase(restaurantId);
      return db.getDashboardStats();
    });
