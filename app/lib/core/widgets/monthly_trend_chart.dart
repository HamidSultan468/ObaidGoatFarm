import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_brand_colors.dart';

/// Income/Expense/Net over time, from the financial-summary report's
/// `data.trend` (`{month, income, expense, net}`, exact decimal strings).
/// Shared by the Reports screen and the Dashboard so both render the exact
/// same real data the exact same way. Chart coordinates are plain doubles
/// (a display concern, same as any chart library) — the underlying figures
/// stay exact decimal strings everywhere they are actually totalled or
/// exported (see `formatMoney`/money.ts).
class MonthlyTrendChart extends StatelessWidget {
  const MonthlyTrendChart({super.key, required this.trend, this.height = 220});

  final List<Map<String, dynamic>> trend;
  final double height;

  double _toDouble(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final brand = AppBrandColors.of(context);
    final incomeSpots = [for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), _toDouble(trend[i]['income']))];
    final expenseSpots = [for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), _toDouble(trend[i]['expense']))];
    final netSpots = [for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), _toDouble(trend[i]['net']))];

    Widget bottomLabel(double value, TitleMeta meta) {
      final index = value.round();
      if (index < 0 || index >= trend.length) return const SizedBox.shrink();
      final month = trend[index]['month']?.toString() ?? '';
      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(month, style: Theme.of(context).textTheme.bodySmall));
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: bottomLabel, reservedSize: 28)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(spots: incomeSpots, color: brand.income, barWidth: 2, dotData: const FlDotData(show: false)),
            LineChartBarData(spots: expenseSpots, color: brand.expense, barWidth: 2, dotData: const FlDotData(show: false)),
            LineChartBarData(spots: netSpots, color: brand.profit, barWidth: 2, dotData: const FlDotData(show: false)),
          ],
        ),
      ),
    );
  }
}

/// A small colored-dot + label, for a chart legend.
class TrendLegend extends StatelessWidget {
  const TrendLegend({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
