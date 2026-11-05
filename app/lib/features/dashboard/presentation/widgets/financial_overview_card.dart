import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_controller.dart';
import '../../../../core/theme/app_brand_colors.dart';
import '../../../../core/widgets/monthly_trend_chart.dart';

const _periodLabels = {
  DashboardTrendPeriod.thisMonth: 'This month',
  DashboardTrendPeriod.last3Months: 'Last 3 months',
  DashboardTrendPeriod.thisYear: 'This year',
};

/// Real income/expense/net trend (the same financial-summary report the
/// Reports screen uses) — shown only to members whose role may view
/// financial reports (see `dashboardFinancialOverviewProvider`'s doc).
class FinancialOverviewCard extends ConsumerWidget {
  const FinancialOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardTrendPeriodProvider);
    final resultAsync = ref.watch(dashboardFinancialOverviewProvider);
    final brand = AppBrandColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Financial Overview', style: Theme.of(context).textTheme.titleMedium)),
                DropdownButton<DashboardTrendPeriod>(
                  value: period,
                  underline: const SizedBox.shrink(),
                  items: [for (final p in DashboardTrendPeriod.values) DropdownMenuItem(value: p, child: Text(_periodLabels[p]!))],
                  onChanged: (value) {
                    if (value != null) ref.read(dashboardTrendPeriodProvider.notifier).select(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            resultAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator())),
              error: (error, _) => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Could not load the financial overview.')),
              data: (result) {
                final trend = (result.data['trend'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
                if (trend.isEmpty) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No activity in this period yet.'));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TrendLegend(color: brand.income, label: 'Income'),
                        const SizedBox(width: 12),
                        TrendLegend(color: brand.expense, label: 'Expenses'),
                        const SizedBox(width: 12),
                        TrendLegend(color: brand.profit, label: 'Profit'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MonthlyTrendChart(trend: trend, height: 200),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
