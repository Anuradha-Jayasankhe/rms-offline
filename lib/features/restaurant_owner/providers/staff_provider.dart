import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/restaurant_database.dart';

// ─── Staff Stream ─────────────────────────────────────────────────────────────

final staffProvider = StreamProvider<List<RestaurantUser>>((ref) {
  final db = ref.watch(restaurantDatabaseProvider);
  if (db == null) return const Stream.empty();
  return db.watchAllUsers();
});

// ─── Staff Notifier ───────────────────────────────────────────────────────────

class StaffNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  StaffNotifier(this._ref) : super(const AsyncValue.data(null));

  RestaurantDatabase? get _db => _ref.read(restaurantDatabaseProvider);
  String get _restaurantId => _ref.read(currentRestaurantIdProvider) ?? '';

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> addStaff({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = _db;
    if (db == null) return;
    final id = generateId();
    await db.upsertUser(
      RestaurantUsersCompanion.insert(
        id: id,
        restaurantId: _restaurantId,
        name: name,
        email: email,
        passwordHash: _hashPassword(password),
        role: role,
        syncStatus: const Value(1),
      ),
    );
    await db.addToSyncQueue(
      id: generateId(),
      tableName: 'restaurant_users',
      recordId: id,
      operation: 'insert',
      payload: {
        'id': id,
        'restaurantId': _restaurantId,
        'name': name,
        'email': email,
        'role': role,
      },
    );
  }

  Future<void> updateStaff({
    required String id,
    required String name,
    required String email,
    required String role,
    String? password,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.upsertUser(
      RestaurantUsersCompanion(
        id: Value(id),
        restaurantId: Value(_restaurantId),
        name: Value(name),
        email: Value(email),
        role: Value(role),
        passwordHash: password != null
            ? Value(_hashPassword(password))
            : const Value.absent(),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> toggleActive(String id, bool isActive) async {
    final db = _db;
    if (db == null) return;
    await db.upsertUser(
      RestaurantUsersCompanion(
        id: Value(id),
        isActive: Value(isActive),
        syncStatus: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> removeStaff(String id) async {
    final db = _db;
    if (db == null) return;
    await db.softDeleteUser(id);
    await db.addToSyncQueue(
      id: generateId(),
      tableName: 'restaurant_users',
      recordId: id,
      operation: 'delete',
      payload: {'id': id},
    );
  }
}

final staffNotifierProvider =
    StateNotifierProvider<StaffNotifier, AsyncValue<void>>(
      (ref) => StaffNotifier(ref),
    );
