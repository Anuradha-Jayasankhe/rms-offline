import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/app_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Restaurants, PlatformAdmins])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed a default platform admin (password: admin123)
          await into(platformAdmins).insert(
            PlatformAdminsCompanion.insert(
              id: 'platform-admin-001',
              name: 'Platform Admin',
              email: 'admin@rms.com',
              passwordHash:
                  '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', // sha256 of admin123
            ),
          );
        },
        onUpgrade: (m, from, to) async {},
      );

  // ── Restaurant queries ────────────────────────────────────────────────────

  Stream<List<Restaurant>> watchAllRestaurants() {
    return (select(restaurants)
          ..where((r) => r.syncStatus.isNotValue(2))
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .watch();
  }

  Future<List<Restaurant>> getAllRestaurants() {
    return (select(restaurants)
          ..where((r) => r.syncStatus.isNotValue(2)))
        .get();
  }

  Future<Restaurant?> getRestaurantById(String id) {
    return (select(restaurants)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertRestaurant(RestaurantsCompanion restaurant) async {
    await into(restaurants).insertOnConflictUpdate(restaurant);
  }

  Future<void> softDeleteRestaurant(String id) async {
    await (update(restaurants)..where((r) => r.id.equals(id))).write(
      const RestaurantsCompanion(
        syncStatus: Value(2),
        isActive: Value(false),
      ),
    );
  }

  Future<List<Restaurant>> getPendingSyncRestaurants() {
    return (select(restaurants)
          ..where((r) => r.syncStatus.equals(1)))
        .get();
  }

  // ── Platform admin queries ────────────────────────────────────────────────

  Future<PlatformAdmin?> getPlatformAdminByEmail(String email) {
    return (select(platformAdmins)
          ..where((a) => a.email.equals(email))
          ..where((a) => a.isActive))
        .getSingleOrNull();
  }

  Future<void> upsertPlatformAdmin(PlatformAdminsCompanion admin) async {
    await into(platformAdmins).insertOnConflictUpdate(admin);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(dbFolder.path, 'rms_offline'));
    await appDir.create(recursive: true);
    final file = File(p.join(appDir.path, 'app.db'));
    return NativeDatabase.createInBackground(file);
  });
}
