import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/constants/app_constants.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/restaurant_database.dart';
import 'package:rms_offline/features/restaurant_owner/providers/staff_provider.dart';
import 'package:rms_offline/widgets/common_widgets.dart';

// ─── Staff Screen ─────────────────────────────────────────────────────────────

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);

    return Scaffold(
      body: staffAsync.when(
        data: (staff) => staff.isEmpty
            ? const _EmptyStaffView()
            : _StaffListView(staff: staff),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
    );
  }

  void _showStaffDialog(
    BuildContext context,
    WidgetRef ref, [
    RestaurantUser? existing,
  ]) {
    showDialog(
      context: context,
      builder: (_) => StaffFormDialog(existing: existing),
    );
  }
}

class _EmptyStaffView extends StatelessWidget {
  const _EmptyStaffView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No staff members yet',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Add staff to manage your restaurant.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _StaffListView extends ConsumerWidget {
  final List<RestaurantUser> staff;
  const _StaffListView({required this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staff.length,
      itemBuilder: (ctx, i) {
        final member = staff[i];
        return _StaffCard(member: member);
      },
    );
  }
}

// ─── Staff Card ───────────────────────────────────────────────────────────────

class _StaffCard extends ConsumerWidget {
  final RestaurantUser member;
  const _StaffCard({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _roleColor(member.role).withValues(alpha: 0.15),
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: _roleColor(member.role),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              member.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            _RoleBadge(role: member.role),
            if (!member.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Inactive',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          member.email,
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'edit') {
              showDialog(
                context: context,
                builder: (_) => StaffFormDialog(existing: member),
              );
            } else if (action == 'toggle') {
              await ref
                  .read(staffNotifierProvider.notifier)
                  .toggleActive(member.id, !member.isActive);
            } else if (action == 'remove') {
              final confirm = await showConfirmDialog(
                context,
                title: 'Remove Staff',
                message:
                    'Remove ${member.name} from the system? This cannot be undone.',
              );
              if (confirm && context.mounted) {
                await ref
                    .read(staffNotifierProvider.notifier)
                    .removeStaff(member.id);
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(member.isActive ? 'Deactivate' : 'Activate'),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppRoles.owner:
        return AppTheme.primaryColor;
      case AppRoles.staff:
        return Colors.teal;
      case AppRoles.kitchen:
        return Colors.orange;
      case AppRoles.cashier:
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (role) {
      case AppRoles.owner:
        color = AppTheme.primaryColor;
        break;
      case AppRoles.staff:
        color = Colors.teal;
        break;
      case AppRoles.kitchen:
        color = Colors.orange;
        break;
      case AppRoles.cashier:
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Staff Form Dialog ────────────────────────────────────────────────────────

class StaffFormDialog extends ConsumerStatefulWidget {
  final RestaurantUser? existing;
  const StaffFormDialog({super.key, this.existing});

  @override
  ConsumerState<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passwordCtrl;
  String _role = AppRoles.staff;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
    _passwordCtrl = TextEditingController();
    _role = widget.existing?.role ?? AppRoles.staff;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (widget.existing == null) {
        await ref
            .read(staffNotifierProvider.notifier)
            .addStaff(
              name: _nameCtrl.text.trim(),
              email: _emailCtrl.text.trim().toLowerCase(),
              password: _passwordCtrl.text,
              role: _role,
            );
      } else {
        await ref
            .read(staffNotifierProvider.notifier)
            .updateStaff(
              id: widget.existing!.id,
              name: _nameCtrl.text.trim(),
              email: _emailCtrl.text.trim().toLowerCase(),
              role: _role,
              password: _passwordCtrl.text.isNotEmpty
                  ? _passwordCtrl.text
                  : null,
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Staff Member' : 'Edit Staff'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.existing == null
                      ? 'Password *'
                      : 'New Password (leave empty to keep)',
                ),
                validator: (v) {
                  if (widget.existing != null) return null; // Optional for edit
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role *'),
                items: const [
                  DropdownMenuItem(value: AppRoles.owner, child: Text('Owner')),
                  DropdownMenuItem(value: AppRoles.staff, child: Text('Staff')),
                  DropdownMenuItem(
                    value: AppRoles.kitchen,
                    child: Text('Kitchen'),
                  ),
                  DropdownMenuItem(
                    value: AppRoles.cashier,
                    child: Text('Cashier'),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
