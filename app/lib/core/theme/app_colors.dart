import 'package:flutter/material.dart';

/// Colors matching the approved dashboard reference design ("Modern Blue"
/// theme — navy sidebar, blue accents, semantic KPI card colors).
class AppColors {
  AppColors._();

  static const Color sidebarNavy = Color(0xFF101C3A);
  static const Color sidebarNavyActive = Color(0xFF1E3A6D);
  static const Color primaryBlue = Color(0xFF2F6FED);
  static const Color accentBlue = Color(0xFF4F8EF7);

  static const Color incomeGreen = Color(0xFF22A559);
  static const Color expenseRed = Color(0xFFE5484D);
  static const Color profitBlue = Color(0xFF3B82F6);
  static const Color balancePurple = Color(0xFF8B5CF6);

  static const Color surfaceLight = Color(0xFFF4F6FB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE3E8F0);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  static const Color surfaceDark = Color(0xFF0B1326);
  static const Color cardDark = Color(0xFF151F38);
  static const Color borderDark = Color(0xFF26304D);
  static const Color textPrimaryDark = Color(0xFFF3F4F6);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  static const Color success = incomeGreen;
  static const Color danger = expenseRed;
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = primaryBlue;
}
