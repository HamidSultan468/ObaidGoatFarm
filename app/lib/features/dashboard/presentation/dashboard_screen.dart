import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accounting/accounting_controller.dart';
import '../../../core/accounting/money_format.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/widgets/not_yet_available_card.dart';
import '../../../core/workspace/workspace_controller.dart';
import '../../../core/workspace/workspace_models.dart';
import 'widgets/backup_status_card.dart';
import 'widgets/goat_farm_card.dart';
import 'widgets/kpi_card.dart';
import 'widgets/quick_actions_card.dart';
import 'widgets/recent_transactions_card.dart';

const _wideBreakpoint = 900.0;

/// The dashboard shell, backed by real Phase 05 accounting data: KPI cards
/// and Recent Transactions are live — see IMPLEMENTATION_STATUS.md.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(workspaceControllerProvider);
    final workspaceName = workspaceState is WorkspaceSelected ? workspaceState.workspace.name : null;

    final cards = <Widget>[
      const NotYetAvailableCard(
        title: 'Financial Overview Chart',
        icon: Icons.show_chart_rounded,
        plannedPhase: 'a charting library — the underlying data is already real',
      ),
      if (workspaceState is WorkspaceSelected)
        QuickActionsCard(workspaceId: workspaceState.workspace.id)
      else
        const NotYetAvailableCard(title: 'Quick Actions', icon: Icons.bolt_rounded, plannedPhase: 'workspace selection'),
      const RecentTransactionsCard(),
      if (workspaceState is WorkspaceSelected) const GoatFarmCard(),
      if (workspaceState is WorkspaceSelected && workspaceState.workspace.canManage) const BackupStatusCard(),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.dashboardTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(workspaceName ?? 'Loading your workspace...', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          if (workspaceState is WorkspaceSelected) const _KpiRow() else const _KpiGrid(cards: _loadingKpis),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth > _wideBreakpoint
                ? _TwoColumn(children: cards)
                : Column(
                    children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pairs cards into rows that size to their content — a fixed-aspect-ratio
/// grid clipped cards whose content (e.g. a transactions list) is taller
/// than the placeholder cards beside them.
class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 16),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

const _loadingKpis = [
  KpiCard(label: 'Total Income', value: '—', icon: Icons.trending_up_rounded, color: AppColors.incomeGreen, isLoading: true),
  KpiCard(label: 'Total Expenses', value: '—', icon: Icons.account_balance_wallet_rounded, color: AppColors.expenseRed, isLoading: true),
  KpiCard(label: 'Net Profit', value: '—', icon: Icons.show_chart_rounded, color: AppColors.profitBlue, isLoading: true),
  KpiCard(label: 'Bank Balance', value: '—', icon: Icons.account_balance_rounded, color: AppColors.balancePurple, isLoading: true),
];

class _KpiRow extends ConsumerWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(profitAndLossProvider);
    final liquid = ref.watch(liquidBalanceProvider);

    String money(AsyncValue<String> value) =>
        value.when(data: (v) => '\$${formatMoney(v)}', loading: () => '—', error: (_, _) => '—');

    return _KpiGrid(
      cards: [
        KpiCard(
          label: 'Total Income',
          value: money(report.whenData((r) => r.totalIncome)),
          icon: Icons.trending_up_rounded,
          color: AppColors.incomeGreen,
          isLoading: report.isLoading,
        ),
        KpiCard(
          label: 'Total Expenses',
          value: money(report.whenData((r) => r.totalExpense)),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.expenseRed,
          isLoading: report.isLoading,
        ),
        KpiCard(
          label: 'Net Profit',
          value: money(report.whenData((r) => r.netProfit)),
          icon: Icons.show_chart_rounded,
          color: AppColors.profitBlue,
          isLoading: report.isLoading,
        ),
        KpiCard(
          label: 'Bank Balance',
          value: money(liquid),
          icon: Icons.account_balance_rounded,
          color: AppColors.balancePurple,
          isLoading: liquid.isLoading,
        ),
      ],
    );
  }
}

/// Fixed pixel row height rather than an aspect ratio, so card content
/// never overflows as the window width changes.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth > _wideBreakpoint ? 4 : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 108,
        ),
        children: cards,
      ),
    );
  }
}
