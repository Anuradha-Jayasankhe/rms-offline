import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_offline/core/theme/app_theme.dart';
import 'package:rms_offline/features/pos/providers/pos_provider.dart';

// ─── Reports Screen ───────────────────────────────────────────────────────────

enum _RPeriod { week, month, year }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _RPeriod _period = _RPeriod.month;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reports', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    const Text('Track your restaurant\'s performance and sales trends',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                // Period tabs
                _ReportPeriodTabs(
                  selected: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Stats ────────────────────────────────────────────────────
            statsAsync.when(
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: _ReportCard(
                      icon: Icons.attach_money_rounded,
                      iconBg: const Color(0xFFEDE9FF),
                      iconColor: AppTheme.primaryColor,
                      title: 'Total Revenue',
                      value: '\$${(stats['todayRevenue'] as double? ?? 0).toStringAsFixed(2)}',
                      change: '+0%',
                      sub: 'vs last ${_period.name}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ReportCard(
                      icon: Icons.shopping_cart_rounded,
                      iconBg: const Color(0xFFD1FAE5),
                      iconColor: AppTheme.successColor,
                      title: 'Total Orders',
                      value: '${stats['todayOrders'] ?? 0}',
                      change: '+0%',
                      sub: 'vs last ${_period.name}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ReportCard(
                      icon: Icons.people_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Unique Customers',
                      value: '0',
                      change: '+0%',
                      sub: 'vs last ${_period.name}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ReportCard(
                      icon: Icons.trending_up_rounded,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Avg. Order Value',
                      value: () {
                        final o = stats['todayOrders'] as int? ?? 0;
                        final r = stats['todayRevenue'] as double? ?? 0;
                        return '\$${o > 0 ? (r / o).toStringAsFixed(2) : '0.00'}';
                      }(),
                      change: '+0%',
                      sub: 'vs last ${_period.name}',
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox(height: 120,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // ── Charts row ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _ChartCard(
                    title: 'Revenue Over Time',
                    subtitle: 'Daily revenue breakdown',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _ChartCard(
                    title: 'Revenue by Category',
                    subtitle: 'Sales distribution by menu category',
                    placeholder: 'No category data',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ChartCard(
                    title: 'Order Status Distribution',
                    subtitle: 'Breakdown of order statuses',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ChartCard(
                    title: 'Peak Hours',
                    subtitle: 'Busiest times of the day',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ChartCard(
                    title: 'Top Menu Items',
                    subtitle: 'Best performing items',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPeriodTabs extends StatelessWidget {
  final _RPeriod selected;
  final ValueChanged<_RPeriod> onChanged;
  const _ReportPeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: _RPeriod.values.map((p) {
          final active = p == selected;
          final label = p == _RPeriod.week
              ? 'This Week'
              : p == _RPeriod.month
                  ? 'This Month'
                  : 'This Year';
          return GestureDetector(
            onTap: () => onChanged(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  if (active)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.calendar_today_rounded,
                          size: 12, color: Colors.white),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : AppTheme.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final String change;
  final String sub;
  const _ReportCard({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.value, required this.change, required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.trending_up_rounded, size: 13, color: AppTheme.successColor),
            const SizedBox(width: 4),
            Text(change, style: const TextStyle(color: AppTheme.successColor,
                fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text(sub, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ]),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String placeholder;
  const _ChartCard({required this.title, required this.subtitle,
      this.placeholder = 'Chart will be displayed here'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.bar_chart_rounded, size: 48, color: Color(0xFFD1D5DB)),
                const SizedBox(height: 8),
                Text(placeholder,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
