import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/constants/app_constants.dart';
import 'package:rms_offline/core/network/api_client.dart';
import 'package:rms_offline/core/network/connectivity_service.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/restaurant_database.dart';

/// Sync Engine: runs in background, syncs pending local changes to server
/// and pulls server updates down to local.
class SyncEngine {
  final Ref _ref;
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncEngine(this._ref) {
    _startTimer();
    _listenForConnectivity();
  }

  void _startTimer() {
    _syncTimer = Timer.periodic(AppConstants.syncInterval, (_) {
      _triggerSync();
    });
  }

  void _listenForConnectivity() {
    _ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      next.whenData((isOnline) {
        if (isOnline) {
          // Internet came back — trigger sync
          _triggerSync();
        }
      });
    });
  }

  Future<void> _triggerSync() async {
    final isOnline = _ref.read(connectivityServiceProvider).isOnline;
    if (!isOnline || _isSyncing) return;

    _isSyncing = true;
    try {
      final restaurantId = _ref.read(currentRestaurantIdProvider);
      if (restaurantId == null) return;
      await syncRestaurant(restaurantId);
    } finally {
      _isSyncing = false;
    }
  }

  /// Full sync for a restaurant: push local changes → pull server updates
  Future<SyncResult> syncRestaurant(String restaurantId) async {
    final manager = _ref.read(databaseManagerProvider);
    final db = manager.getRestaurantDatabase(restaurantId);
    final api = _ref.read(apiClientProvider);

    int pushed = 0;
    int pulled = 0;
    final errors = <String>[];

    try {
      // 1. Push local pending changes
      final pendingItems = await db.getPendingSyncItems();
      if (pendingItems.isNotEmpty) {
        final changes = pendingItems
            .map(
              (item) => {
                'id': item.id,
                'table': item.entityTable,
                'recordId': item.recordId,
                'operation': item.operation,
                'payload': jsonDecode(item.payload),
              },
            )
            .toList();

        try {
          await api.pushSync(restaurantId, changes);
          for (final item in pendingItems) {
            await db.markSyncItemProcessed(item.id);
          }
          pushed = pendingItems.length;
        } catch (e) {
          for (final item in pendingItems) {
            await db.incrementSyncRetry(item.id, e.toString());
          }
          errors.add('Push failed: $e');
        }
      }

      // 2. Pull server updates
      try {
        final response = await api.pullSync(restaurantId, null);
        final serverChanges = response['changes'] as List<dynamic>? ?? [];
        await _applyServerChanges(db, serverChanges);
        pulled = serverChanges.length;
      } catch (e) {
        errors.add('Pull failed: $e');
      }

      // 3. Clean up processed items
      await db.clearProcessedSyncItems();
    } catch (e) {
      errors.add('Sync error: $e');
    }

    return SyncResult(pushed: pushed, pulled: pulled, errors: errors);
  }

  Future<void> _applyServerChanges(
    RestaurantDatabase db,
    List<dynamic> changes,
  ) async {
    for (final change in changes) {
      final table = change['table'] as String;
      final operation = change['operation'] as String;
      final payload = change['payload'] as Map<String, dynamic>;

      try {
        switch (table) {
          case 'menu_items':
            await _applyMenuItemChange(db, operation, payload);
          case 'ingredients':
            await _applyIngredientChange(db, operation, payload);
          case 'orders':
            await _applyOrderChange(db, operation, payload);
          case 'restaurant_users':
            await _applyUserChange(db, operation, payload);
        }
      } catch (_) {
        // Skip individual item errors
      }
    }
  }

  Future<void> _applyMenuItemChange(
    RestaurantDatabase db,
    String op,
    Map<String, dynamic> p,
  ) async {
    if (op == 'delete') {
      await db.softDeleteMenuItem(p['id'] as String);
    } else {
      await db.upsertMenuItem(
        MenuItemsCompanion.insert(
          id: p['id'] as String,
          restaurantId: p['restaurantId'] as String,
          name: p['name'] as String,
          sellingPrice: (p['sellingPrice'] as num).toDouble(),
          syncStatus: const drift.Value(0),
          version: drift.Value((p['version'] as int?) ?? 1),
        ),
      );
    }
  }

  Future<void> _applyIngredientChange(
    RestaurantDatabase db,
    String op,
    Map<String, dynamic> p,
  ) async {
    if (op == 'delete') {
      // soft delete
    } else {
      await db.upsertIngredient(
        IngredientsCompanion.insert(
          id: p['id'] as String,
          restaurantId: p['restaurantId'] as String,
          name: p['name'] as String,
          unit: p['unit'] as String,
          syncStatus: const drift.Value(0),
        ),
      );
    }
  }

  Future<void> _applyOrderChange(
    RestaurantDatabase db,
    String op,
    Map<String, dynamic> p,
  ) async {
    if (op != 'delete') {
      await db.upsertOrder(
        OrdersCompanion.insert(
          id: p['id'] as String,
          restaurantId: p['restaurantId'] as String,
          status: drift.Value(p['status'] as String? ?? 'pending'),
          syncStatus: const drift.Value(0),
        ),
      );
    }
  }

  Future<void> _applyUserChange(
    RestaurantDatabase db,
    String op,
    Map<String, dynamic> p,
  ) async {
    if (op != 'delete') {
      await db.upsertUser(
        RestaurantUsersCompanion.insert(
          id: p['id'] as String,
          restaurantId: p['restaurantId'] as String,
          name: p['name'] as String,
          email: p['email'] as String,
          passwordHash: p['passwordHash'] as String? ?? '',
          role: p['role'] as String,
          syncStatus: const drift.Value(0),
        ),
      );
    }
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}

class SyncResult {
  final int pushed;
  final int pulled;
  final List<String> errors;

  SyncResult({
    required this.pushed,
    required this.pulled,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

// ─── Sync State ───────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSync;
  final String? lastError;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastSync,
    this.lastError,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSync,
    String? lastError,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSync: lastSync ?? this.lastSync,
      lastError: lastError,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  SyncEngine? _engine;

  SyncNotifier(this._ref) : super(const SyncState()) {
    _engine = SyncEngine(_ref);
    _watchPendingCount();
  }

  void _watchPendingCount() {
    _ref.listen(currentRestaurantIdProvider, (prev, restaurantId) {
      if (restaurantId != null) {
        _refreshPendingCount(restaurantId);
      }
    });
  }

  Future<void> _refreshPendingCount(String restaurantId) async {
    final db = _ref
        .read(databaseManagerProvider)
        .getRestaurantDatabase(restaurantId);
    final items = await db.getPendingSyncItems();
    state = state.copyWith(pendingCount: items.length);
  }

  Future<void> syncNow() async {
    final restaurantId = _ref.read(currentRestaurantIdProvider);
    if (restaurantId == null) return;

    state = state.copyWith(status: SyncStatus.syncing);
    try {
      final result = await _engine!.syncRestaurant(restaurantId);
      state = state.copyWith(
        status: result.hasErrors ? SyncStatus.error : SyncStatus.success,
        lastSync: DateTime.now(),
        lastError: result.hasErrors ? result.errors.join(', ') : null,
        pendingCount: 0,
      );
      await _refreshPendingCount(restaurantId);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, lastError: e.toString());
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});
