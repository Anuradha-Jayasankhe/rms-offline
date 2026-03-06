class AppConstants {
  static const String appName = 'RMS Offline';
  static const String appVersion = '1.0.0';

  // API
  static const String baseUrl = 'http://localhost:3000/api';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Sync
  static const Duration syncInterval = Duration(minutes: 5);
  static const int maxSyncRetries = 3;
  static const String syncQueueTable = 'sync_queue';

  // Auth
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';
  static const String restaurantKey = 'current_restaurant';
  static const String roleKey = 'user_role';

  // Roles
  static const String rolePlatformAdmin = 'platform_admin';
  static const String roleOwner = 'owner';
  static const String roleStaff = 'staff';
  static const String roleKitchen = 'kitchen';
  static const String roleCashier = 'cashier';

  // Sync Status
  static const int syncStatusSynced = 0;
  static const int syncStatusPending = 1;
  static const int syncStatusDeleted = 2;
  static const int syncStatusConflict = 3;

  // Order Status
  static const String orderStatusPending = 'pending';
  static const String orderStatusPreparing = 'preparing';
  static const String orderStatusReady = 'ready';
  static const String orderStatusServed = 'served';
  static const String orderStatusCancelled = 'cancelled';

  // Table Status
  static const String tableStatusAvailable = 'available';
  static const String tableStatusOccupied = 'occupied';
  static const String tableStatusReserved = 'reserved';

  // Payment Status
  static const String paymentStatusUnpaid = 'unpaid';
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusPartial = 'partial';

  // Payment Methods
  static const String paymentCash = 'cash';
  static const String paymentCard = 'card';
  static const String paymentOnline = 'online';
}

/// Shorthand role constants for use in switch-case and DropdownMenuItems.
class AppRoles {
  static const String platformAdmin = 'platform_admin';
  static const String owner = 'owner';
  static const String staff = 'staff';
  static const String kitchen = 'kitchen';
  static const String cashier = 'cashier';
}
