import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/widgets/not_yet_available_card.dart';
import '../../../core/workspace/workspace_controller.dart';
import '../../../core/workspace/workspace_models.dart';
import 'widgets/kpi_card.dart';

/// The Phase 04 dashboard shell. KPI cards show a genuine zero state — no
/// financial data exists yet (the accounting engine is Phase 05 scope) —
/// rather than the illustrative numbers from the approved reference mockup.
/// See IMPLEMENTATION_STATUS.md.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(workspaceControllerProvider);
    final workspaceName = workspaceState is WorkspaceSelected ? workspaceState.workspace.name : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            workspaceName != null
                ? '$workspaceName — figures below are empty until real data is recorded (Phase 05).'
                : 'Loading your workspace...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final cards = const [
                KpiCard(label: 'Total Income', value: '\$0.00', icon: Icons.trending_up_rounded, color: AppColors.incomeGreen),
                KpiCard(label: 'Total Expenses', value: '\$0.00', icon: Icons.account_balance_wallet_rounded, color: AppColors.expenseRed),
                KpiCard(label: 'Net Profit', value: '\$0.00', icon: Icons.show_chart_rounded, color: AppColors.profitBlue),
                KpiCard(label: 'Bank Balance', value: '\$0.00', icon: Icons.account_balance_rounded, color: AppColors.balancePurple),
              ];
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: isWide ? 2.4 : 1.8,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final children = const [
                NotYetAvailableCard(title: 'Financial Overview', icon: Icons.show_chart_rounded, plannedPhase: 'Phase 05 — Financial Management'),
                NotYetAvailableCard(title: 'Goat Farm Management', icon: Icons.pets_rounded, plannedPhase: 'Phase 06 — Goat Farm Management'),
                NotYetAvailableCard(title: 'Recent Transactions', icon: Icons.receipt_long_rounded, plannedPhase: 'Phase 05 — Financial Management'),
                NotYetAvailableCard(title: 'Cloud Backup Status', icon: Icons.cloud_done_rounded, plannedPhase: 'Phase 10 — Cloud Backup & Storage'),
              ];
              if (!isWide) {
                return Column(
                  children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList(),
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.6,
                children: children,
              );
            },
          ),
        ],
      ),
    );
  }
}
