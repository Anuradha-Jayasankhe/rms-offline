import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/app_database.dart';
import 'package:rms_offline/features/auth/providers/auth_provider.dart';
import 'package:rms_offline/features/platform_admin/providers/platform_admin_provider.dart';
import 'package:rms_offline/widgets/common_widgets.dart';

// ─── Platform Admin Dashboard ─────────────────────────────────────────────────

class PlatformAdminDashboard extends ConsumerWidget {
  const PlatformAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final restaurantsAsync = ref.watch(restaurantStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Admin Dashboard'),
        actions: [
          const SyncStatusWidget(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${auth.name ?? 'Admin'}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage all restaurants from this panel',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  restaurantsAsync.when(
                    data: (restaurants) => Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Total Restaurants',
                            value: '${restaurants.length}',
                            icon: Icons.restaurant,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            title: 'Active Restaurants',
                            value:
                                '${restaurants.where((r) => r.isActive).length}',
                            icon: Icons.check_circle,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            title: 'Inactive',
                            value:
                                '${restaurants.where((r) => !r.isActive).length}',
                            icon: Icons.cancel,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Restaurants',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.go('/admin/restaurants/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('New Restaurant'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: restaurantsAsync.when(
                      data: (restaurants) =>
                          RestaurantListView(restaurants: restaurants),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Restaurant List View ─────────────────────────────────────────────────────

class RestaurantListView extends ConsumerWidget {
  final List<Restaurant> restaurants;
  const RestaurantListView({super.key, required this.restaurants});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (restaurants.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No restaurants yet. Create one to get started.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: restaurants.length,
      itemBuilder: (ctx, i) {
        final r = restaurants[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: r.isActive ? AppTheme.primaryColor : Colors.grey,
              child: Text(
                r.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              r.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.address != null) Text(r.address!),
                if (r.email != null)
                  Text(
                    r.email!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(
                    r.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: r.isActive ? AppTheme.successColor : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  side: BorderSide.none,
                  backgroundColor: r.isActive
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    r.subscriptionPlan,
                    style: const TextStyle(fontSize: 12),
                  ),
                  side: BorderSide.none,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    switch (action) {
                      case 'toggle':
                        await ref
                            .read(platformAdminProvider.notifier)
                            .toggleRestaurantStatus(r.id, !r.isActive);
                      case 'delete':
                        final confirm = await showConfirmDialog(
                          context,
                          title: 'Delete Restaurant',
                          message:
                              'Are you sure you want to delete ${r.name}? This cannot be undone.',
                          confirmText: 'Delete',
                          confirmColor: AppTheme.errorColor,
                        );
                        if (confirm) {
                          await ref
                              .read(platformAdminProvider.notifier)
                              .deleteRestaurant(r.id);
                        }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(r.isActive ? 'Deactivate' : 'Activate'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Create Restaurant Screen ─────────────────────────────────────────────────

class CreateRestaurantScreen extends ConsumerStatefulWidget {
  const CreateRestaurantScreen({super.key});

  @override
  ConsumerState<CreateRestaurantScreen> createState() =>
      _CreateRestaurantScreenState();
}

class _CreateRestaurantScreenState
    extends ConsumerState<CreateRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerEmailCtrl = TextEditingController();
  final _ownerPasswordCtrl = TextEditingController();
  String _plan = 'basic';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _ownerPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(platformAdminProvider.notifier)
          .createRestaurant(
            name: _nameCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            ownerName: _ownerNameCtrl.text.trim(),
            ownerEmail: _ownerEmailCtrl.text.trim(),
            ownerPassword: _ownerPasswordCtrl.text,
            subscriptionPlan: _plan,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Restaurant created successfully! A new database has been initialized.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/admin');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Restaurant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: 700,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(32),
              children: [
                // Restaurant Info Section
                _SectionHeader(
                  title: '1. Restaurant Information',
                  icon: Icons.restaurant,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Restaurant Name *',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Restaurant Email',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _plan,
                  decoration: const InputDecoration(
                    labelText: 'Subscription Plan',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'basic', child: Text('Basic')),
                    DropdownMenuItem(value: 'pro', child: Text('Pro')),
                    DropdownMenuItem(
                      value: 'enterprise',
                      child: Text('Enterprise'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _plan = v ?? _plan),
                ),
                const SizedBox(height: 32),
                // Owner Account Section
                _SectionHeader(title: '2. Owner Account', icon: Icons.person),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ownerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Owner Name *',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _ownerEmailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Owner Email *',
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Valid email'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ownerPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Owner Password *',
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 chars' : null,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A new isolated SQLite database will be created for this restaurant. The owner can log in immediately.',
                          style: TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.go('/admin'),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _create,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_business),
                      label: const Text('Create Restaurant'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 16),
        const Expanded(child: Divider()),
      ],
    );
  }
}
