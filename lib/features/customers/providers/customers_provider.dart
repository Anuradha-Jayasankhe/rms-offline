import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/database/tables/restaurant_tables.dart';
import 'package:rms_offline/features/auth/providers/auth_provider.dart';

// ─── Customers Provider ──────────────────────────────────────────────────────

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final restaurantId = ref.watch(currentRestaurantIdProvider);
  if (restaurantId == null) return const Stream.empty();
  return ref
      .watch(databaseManagerProvider)
      .getRestaurantDatabase(restaurantId)
      .watchAllCustomers();
});

// ─── Customers Notifier ──────────────────────────────────────────────────────

class CustomersNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CustomersNotifier(this._ref) : super(const AsyncValue.data(null));

  RestaurantDatabase get _db {
    final id = _ref.read(currentRestaurantIdProvider)!;
    return _ref.read(databaseManagerProvider).getRestaurantDatabase(id);
  }

  String get _restaurantId => _ref.read(currentRestaurantIdProvider)!;

  Future<void> addCustomer({
    required String name,
    String? email,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.upsertCustomer(
        CustomersCompanion.insert(
          id: generateId(),
          restaurantId: _restaurantId,
          name: name,
          email: Value(email),
          phone: Value(phone),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    String? email,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.upsertCustomer(
        CustomersCompanion(
          id: Value(id),
          restaurantId: Value(_restaurantId),
          name: Value(name),
          email: Value(email),
          phone: Value(phone),
          updatedAt: Value(DateTime.now()),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteCustomer(String id) async {
    await _db.deleteCustomer(id);
  }
}

final customersNotifierProvider =
    StateNotifierProvider<CustomersNotifier, AsyncValue<void>>(
        (ref) => CustomersNotifier(ref));
