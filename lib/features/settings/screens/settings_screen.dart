import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';

// ─── Settings Screen ──────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // General form controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postCodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  String _currency = 'LKR';
  String _timezone = 'UTC';

  static const _currencies = ['LKR', 'USD', 'EUR', 'GBP', 'INR', 'AUD'];
  static const _timezones = ['UTC', 'UTC+5:30', 'UTC+3', 'UTC+8', 'UTC-5'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 20),
            // Tab bar
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(icon: Row(children: [Icon(Icons.settings_outlined, size: 16), SizedBox(width: 6), Text('General')]), height: 44),
                  Tab(icon: Row(children: [Icon(Icons.access_time_rounded, size: 16), SizedBox(width: 6), Text('Opening Hours')]), height: 44),
                  Tab(icon: Row(children: [Icon(Icons.credit_card_rounded, size: 16), SizedBox(width: 6), Text('Payments')]), height: 44),
                  Tab(icon: Row(children: [Icon(Icons.percent_rounded, size: 16), SizedBox(width: 6), Text('Taxes & Charges')]), height: 44),
                  Tab(icon: Row(children: [Icon(Icons.receipt_outlined, size: 16), SizedBox(width: 6), Text('Receipt')]), height: 44),
                  Tab(icon: Row(children: [Icon(Icons.link_rounded, size: 16), SizedBox(width: 6), Text('Integrations')]), height: 44),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _GeneralTab(
                    nameCtrl: _nameCtrl,
                    phoneCtrl: _phoneCtrl,
                    emailCtrl: _emailCtrl,
                    websiteCtrl: _websiteCtrl,
                    descCtrl: _descCtrl,
                    streetCtrl: _streetCtrl,
                    cityCtrl: _cityCtrl,
                    stateCtrl: _stateCtrl,
                    postCodeCtrl: _postCodeCtrl,
                    countryCtrl: _countryCtrl,
                    currency: _currency,
                    timezone: _timezone,
                    currencies: _currencies,
                    timezones: _timezones,
                    onCurrencyChanged: (v) => setState(() => _currency = v!),
                    onTimezoneChanged: (v) => setState(() => _timezone = v!),
                  ),
                  const _PlaceholderTab(
                      icon: Icons.access_time_rounded,
                      title: 'Opening Hours',
                      description: 'Configure your restaurant\'s operating hours'),
                  const _PlaceholderTab(
                      icon: Icons.credit_card_rounded,
                      title: 'Payment Methods',
                      description: 'Configure accepted payment methods'),
                  const _PlaceholderTab(
                      icon: Icons.percent_rounded,
                      title: 'Taxes & Charges',
                      description: 'Set up tax rates and service charges'),
                  const _PlaceholderTab(
                      icon: Icons.receipt_outlined,
                      title: 'Receipt Settings',
                      description: 'Customize your receipt header and footer'),
                  const _PlaceholderTab(
                      icon: Icons.link_rounded,
                      title: 'Integrations',
                      description: 'Connect third-party services'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── General Tab ───────────────────────────────────────────────────────────────

class _GeneralTab extends StatelessWidget {
  final TextEditingController nameCtrl, phoneCtrl, emailCtrl, websiteCtrl,
      descCtrl, streetCtrl, cityCtrl, stateCtrl, postCodeCtrl, countryCtrl;
  final String currency;
  final String timezone;
  final List<String> currencies;
  final List<String> timezones;
  final ValueChanged<String?> onCurrencyChanged;
  final ValueChanged<String?> onTimezoneChanged;

  const _GeneralTab({
    required this.nameCtrl, required this.phoneCtrl, required this.emailCtrl,
    required this.websiteCtrl, required this.descCtrl, required this.streetCtrl,
    required this.cityCtrl, required this.stateCtrl, required this.postCodeCtrl,
    required this.countryCtrl, required this.currency, required this.timezone,
    required this.currencies, required this.timezones,
    required this.onCurrencyChanged, required this.onTimezoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _SettingsCard(
            title: 'Restaurant Information',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SettingsField(ctrl: nameCtrl, label: 'Restaurant Name'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SettingsField(ctrl: phoneCtrl, label: 'Phone Number'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SettingsField(ctrl: emailCtrl, label: 'Email Address'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SettingsField(ctrl: websiteCtrl, label: 'Website',
                          hint: 'https://yourrestaurant.com'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsField(ctrl: descCtrl, label: 'Description',
                    hint: 'Tell your customers about your restaurant...',
                    maxLines: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Address',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Street', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                _SettingsField(ctrl: streetCtrl, label: ''),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _SettingsField(ctrl: cityCtrl, label: 'City')),
                  const SizedBox(width: 16),
                  Expanded(child: _SettingsField(ctrl: stateCtrl, label: 'State / Province')),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _SettingsField(ctrl: postCodeCtrl, label: 'Post Code')),
                  const SizedBox(width: 16),
                  Expanded(child: _SettingsField(ctrl: countryCtrl, label: 'Country')),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Currency', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: currency,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
                        items: const ['LKR', 'USD', 'EUR', 'GBP', 'INR', 'AUD']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: onCurrencyChanged,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Timezone', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: timezone,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
                        items: const ['UTC', 'UTC+5:30', 'UTC+3', 'UTC+8', 'UTC-5']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: onTimezoneChanged,
                      ),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save Changes'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final int maxLines;
  const _SettingsField(
      {required this.ctrl, required this.label, this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        if (label.isNotEmpty) const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _PlaceholderTab(
      {required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 36, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () {}, child: const Text('Configure')),
        ],
      ),
    );
  }
}
