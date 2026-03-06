import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/database/app_database.dart';
import 'package:rms_offline/database/database_manager.dart';
import 'package:rms_offline/features/auth/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPlatformAdmin = true;
  bool _obscurePassword = true;
  String? _selectedRestaurantId;
  List<Restaurant> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    final db = ref.read(appDatabaseProvider);
    final list = await db.getAllRestaurants();
    if (mounted) {
      setState(() => _restaurants = list);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    bool success;
    if (_isPlatformAdmin) {
      success = await ref
          .read(authProvider.notifier)
          .loginAsPlatformAdmin(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } else {
      if (_selectedRestaurantId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a restaurant')),
        );
        return;
      }
      success = await ref
          .read(authProvider.notifier)
          .loginAsRestaurantUser(
            _selectedRestaurantId!,
            _emailController.text.trim(),
            _passwordController.text,
          );
    }

    if (!success && mounted) {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Login failed'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Row(
        children: [
          // ── Left Panel ─────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.sidebarColor, AppTheme.primaryColor],
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant, color: Colors.white, size: 80),
                  SizedBox(height: 24),
                  Text(
                    'RMS Offline',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Restaurant Management System',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Offline-First • Multi-Tenant',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          // ── Right Panel (Login Form) ────────────────────────────────────
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      // Login type toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            _buildToggleBtn(
                              'Platform Admin',
                              _isPlatformAdmin,
                              () {
                                setState(() => _isPlatformAdmin = true);
                              },
                            ),
                            _buildToggleBtn(
                              'Restaurant',
                              !_isPlatformAdmin,
                              () {
                                setState(() => _isPlatformAdmin = false);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Restaurant selector
                      if (!_isPlatformAdmin) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRestaurantId,
                          decoration: const InputDecoration(
                            labelText: 'Select Restaurant',
                            prefixIcon: Icon(Icons.restaurant),
                          ),
                          items: _restaurants
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(r.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedRestaurantId = v),
                          validator: (v) => v == null && !_isPlatformAdmin
                              ? 'Select a restaurant'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.length < 4 ? 'Enter password' : null,
                      ),
                      const SizedBox(height: 32),
                      // Login button
                      ElevatedButton(
                        onPressed: authState.isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Default admin: admin@rms.com / admin123',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
