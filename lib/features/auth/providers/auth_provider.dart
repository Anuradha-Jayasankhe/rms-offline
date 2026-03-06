import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rms_offline/core/constants/app_constants.dart';
import 'package:rms_offline/core/network/api_client.dart';
import 'package:rms_offline/core/network/connectivity_service.dart';
import 'package:rms_offline/core/utils/id_generator.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/database/app_database.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/database/tables/app_tables.dart';
import 'package:rms_offline/database/tables/restaurant_tables.dart';
import 'package:drift/drift.dart' hide Column;

// ─── Auth State ─────────────────────────────────────────────────────────────

enum AuthRole { platformAdmin, owner, staff, kitchen, cashier, unauthenticated }

class AuthState {
  final String? userId;
  final String? restaurantId;
  final String? name;
  final String? email;
  final AuthRole role;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.userId,
    this.restaurantId,
    this.name,
    this.email,
    this.role = AuthRole.unauthenticated,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => role != AuthRole.unauthenticated;
  bool get isPlatformAdmin => role == AuthRole.platformAdmin;
  bool get isOwner => role == AuthRole.owner;

  AuthState copyWith({
    String? userId,
    String? restaurantId,
    String? name,
    String? email,
    AuthRole? role,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Auth Notifier ───────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _restoreSession();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(AppConstants.userKey);
    final restaurantId = prefs.getString(AppConstants.restaurantKey);
    final roleStr = prefs.getString(AppConstants.roleKey);

    if (userId != null && roleStr != null) {
      final role = _roleFromString(roleStr);
      if (restaurantId != null) {
        _ref.read(currentRestaurantIdProvider.notifier).state = restaurantId;
      }
      // Re-fetch user name from DB
      String? name;
      String? email;
      if (role == AuthRole.platformAdmin) {
        final db = _ref.read(appDatabaseProvider);
        final admin = await (db.select(
          db.platformAdmins,
        )..where((a) => a.id.equals(userId))).getSingleOrNull();
        name = admin?.name;
        email = admin?.email;
      } else if (restaurantId != null) {
        final db = _ref
            .read(databaseManagerProvider)
            .getRestaurantDatabase(restaurantId);
        final user = await (db.select(
          db.restaurantUsers,
        )..where((u) => u.id.equals(userId))).getSingleOrNull();
        name = user?.name;
        email = user?.email;
      }

      state = AuthState(
        userId: userId,
        restaurantId: restaurantId,
        name: name,
        email: email,
        role: role,
      );
    }
  }

  Future<bool> loginAsPlatformAdmin(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final db = _ref.read(appDatabaseProvider);
      final admin = await db.getPlatformAdminByEmail(email);

      if (admin == null) {
        // Try online login
        final isOnline = _ref.read(connectivityServiceProvider).isOnline;
        if (isOnline) {
          return await _onlineLogin(email, password, null);
        }
        state = state.copyWith(isLoading: false, error: 'Admin not found');
        return false;
      }

      if (admin.passwordHash != _hashPassword(password)) {
        state = state.copyWith(isLoading: false, error: 'Invalid password');
        return false;
      }

      await _saveSession(
        admin.id,
        null,
        admin.name,
        admin.email,
        AuthRole.platformAdmin,
      );
      state = AuthState(
        userId: admin.id,
        restaurantId: null,
        name: admin.name,
        email: admin.email,
        role: AuthRole.platformAdmin,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> loginAsRestaurantUser(
    String restaurantId,
    String email,
    String password,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final manager = _ref.read(databaseManagerProvider);
      final db = manager.getRestaurantDatabase(restaurantId);
      final user = await db.getUserByEmail(email);

      if (user == null) {
        final isOnline = _ref.read(connectivityServiceProvider).isOnline;
        if (isOnline) {
          return await _onlineLogin(email, password, restaurantId);
        }
        state = state.copyWith(isLoading: false, error: 'User not found');
        return false;
      }

      if (user.passwordHash != _hashPassword(password)) {
        state = state.copyWith(isLoading: false, error: 'Invalid password');
        return false;
      }

      final role = _roleFromString(user.role);
      _ref.read(currentRestaurantIdProvider.notifier).state = restaurantId;
      await _saveSession(user.id, restaurantId, user.name, user.email, role);
      state = AuthState(
        userId: user.id,
        restaurantId: restaurantId,
        name: user.name,
        email: user.email,
        role: role,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _onlineLogin(
    String email,
    String password,
    String? restaurantId,
  ) async {
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.login(email, password);
      final token = response['token'] as String?;
      if (token == null) {
        state = state.copyWith(isLoading: false, error: 'Login failed');
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);

      final userData = response['user'] as Map<String, dynamic>;
      final roleStr = userData['role'] as String;
      final role = _roleFromString(roleStr);
      final userId = userData['id'] as String;
      final name = userData['name'] as String;
      final userEmail = userData['email'] as String;
      final resId = restaurantId ?? userData['restaurantId'] as String?;

      if (resId != null) {
        _ref.read(currentRestaurantIdProvider.notifier).state = resId;
      }
      await _saveSession(userId, resId, name, userEmail, role);
      state = AuthState(
        userId: userId,
        restaurantId: resId,
        name: name,
        email: userEmail,
        role: role,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Network error: $e');
      return false;
    }
  }

  Future<void> _saveSession(
    String userId,
    String? restaurantId,
    String? name,
    String email,
    AuthRole role,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, userId);
    await prefs.setString(AppConstants.roleKey, _roleToString(role));
    if (restaurantId != null) {
      await prefs.setString(AppConstants.restaurantKey, restaurantId);
    } else {
      await prefs.remove(AppConstants.restaurantKey);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userKey);
    await prefs.remove(AppConstants.restaurantKey);
    await prefs.remove(AppConstants.roleKey);
    await prefs.remove(AppConstants.tokenKey);
    _ref.read(currentRestaurantIdProvider.notifier).state = null;
    state = const AuthState();
  }

  AuthRole _roleFromString(String role) {
    switch (role) {
      case 'platform_admin':
        return AuthRole.platformAdmin;
      case 'owner':
        return AuthRole.owner;
      case 'staff':
        return AuthRole.staff;
      case 'kitchen':
        return AuthRole.kitchen;
      case 'cashier':
        return AuthRole.cashier;
      default:
        return AuthRole.unauthenticated;
    }
  }

  String _roleToString(AuthRole role) {
    switch (role) {
      case AuthRole.platformAdmin:
        return 'platform_admin';
      case AuthRole.owner:
        return 'owner';
      case AuthRole.staff:
        return 'staff';
      case AuthRole.kitchen:
        return 'kitchen';
      case AuthRole.cashier:
        return 'cashier';
      default:
        return '';
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
