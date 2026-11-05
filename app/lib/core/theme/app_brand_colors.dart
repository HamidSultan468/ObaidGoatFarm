import 'package:flutter/material.dart';

/// Brand colors that differ between theme variants (sidebar, KPI/chart
/// semantic colors) — looked up via [AppBrandColors.of] so the sidebar,
/// dashboard KPI cards, and trend charts actually change when the user
/// switches theme in Settings, instead of staying hardcoded to one palette.
class AppBrandColors extends ThemeExtension<AppBrandColors> {
  const AppBrandColors({
    required this.sidebar,
    required this.sidebarActive,
    required this.income,
    required this.expense,
    required this.profit,
    required this.balance,
  });

  final Color sidebar;
  final Color sidebarActive;
  final Color income;
  final Color expense;
  final Color profit;
  final Color balance;

  static AppBrandColors of(BuildContext context) => Theme.of(context).extension<AppBrandColors>()!;

  @override
  AppBrandColors copyWith({Color? sidebar, Color? sidebarActive, Color? income, Color? expense, Color? profit, Color? balance}) {
    return AppBrandColors(
      sidebar: sidebar ?? this.sidebar,
      sidebarActive: sidebarActive ?? this.sidebarActive,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      profit: profit ?? this.profit,
      balance: balance ?? this.balance,
    );
  }

  @override
  AppBrandColors lerp(ThemeExtension<AppBrandColors>? other, double t) {
    if (other is! AppBrandColors) return this;
    return AppBrandColors(
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarActive: Color.lerp(sidebarActive, other.sidebarActive, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      profit: Color.lerp(profit, other.profit, t)!,
      balance: Color.lerp(balance, other.balance, t)!,
    );
  }
}
