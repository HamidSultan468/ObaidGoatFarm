import 'package:flutter/material.dart';
import 'app_brand_colors.dart';
import 'app_colors.dart';
import 'app_colors_professional.dart';

/// The two selectable visual themes. "Modern Blue" is the original design
/// (navy sidebar, blue accents); "Professional" is a second, more formal
/// enterprise-financial look (charcoal sidebar, emerald/gold accents) added
/// alongside it — Settings lets the user pick either, Modern Blue stays the
/// default so nothing changes for anyone who doesn't choose.
enum AppThemeVariant {
  modernBlue('Modern Blue'),
  professional('Professional');

  const AppThemeVariant(this.label);
  final String label;

  ThemeData light() => switch (this) {
    AppThemeVariant.modernBlue => AppTheme._build(
      brightness: Brightness.light,
      seed: AppColors.primaryBlue,
      surface: AppColors.surfaceLight,
      card: AppColors.cardLight,
      border: AppColors.borderLight,
      textPrimary: AppColors.textPrimaryLight,
      textSecondary: AppColors.textSecondaryLight,
      cardRadius: 16,
      inputRadius: 10,
      brand: const AppBrandColors(
        sidebar: AppColors.sidebarNavy,
        sidebarActive: AppColors.sidebarNavyActive,
        income: AppColors.incomeGreen,
        expense: AppColors.expenseRed,
        profit: AppColors.profitBlue,
        balance: AppColors.balancePurple,
      ),
    ),
    AppThemeVariant.professional => AppTheme._build(
      brightness: Brightness.light,
      seed: AppColorsProfessional.primaryEmerald,
      surface: AppColorsProfessional.surfaceLight,
      card: AppColorsProfessional.cardLight,
      border: AppColorsProfessional.borderLight,
      textPrimary: AppColorsProfessional.textPrimaryLight,
      textSecondary: AppColorsProfessional.textSecondaryLight,
      cardRadius: 10,
      inputRadius: 6,
      headlineWeight: FontWeight.w800,
      brand: const AppBrandColors(
        sidebar: AppColorsProfessional.sidebarCharcoal,
        sidebarActive: AppColorsProfessional.sidebarCharcoalActive,
        income: AppColorsProfessional.incomeGreen,
        expense: AppColorsProfessional.expenseRed,
        profit: AppColorsProfessional.profitGold,
        balance: AppColorsProfessional.balanceSlate,
      ),
    ),
  };

  ThemeData dark() => switch (this) {
    AppThemeVariant.modernBlue => AppTheme._build(
      brightness: Brightness.dark,
      seed: AppColors.primaryBlue,
      surface: AppColors.surfaceDark,
      card: AppColors.cardDark,
      border: AppColors.borderDark,
      textPrimary: AppColors.textPrimaryDark,
      textSecondary: AppColors.textSecondaryDark,
      cardRadius: 16,
      inputRadius: 10,
      brand: const AppBrandColors(
        sidebar: AppColors.sidebarNavy,
        sidebarActive: AppColors.sidebarNavyActive,
        income: AppColors.incomeGreen,
        expense: AppColors.expenseRed,
        profit: AppColors.profitBlue,
        balance: AppColors.balancePurple,
      ),
    ),
    AppThemeVariant.professional => AppTheme._build(
      brightness: Brightness.dark,
      seed: AppColorsProfessional.primaryEmerald,
      surface: AppColorsProfessional.surfaceDark,
      card: AppColorsProfessional.cardDark,
      border: AppColorsProfessional.borderDark,
      textPrimary: AppColorsProfessional.textPrimaryDark,
      textSecondary: AppColorsProfessional.textSecondaryDark,
      cardRadius: 10,
      inputRadius: 6,
      headlineWeight: FontWeight.w800,
      brand: const AppBrandColors(
        sidebar: AppColorsProfessional.sidebarCharcoal,
        sidebarActive: AppColorsProfessional.sidebarCharcoalActive,
        income: AppColorsProfessional.incomeGreen,
        expense: AppColorsProfessional.expenseRed,
        profit: AppColorsProfessional.profitGold,
        balance: AppColorsProfessional.balanceSlate,
      ),
    ),
  };
}

class AppTheme {
  AppTheme._();

  /// Kept for any code that hasn't moved to [AppThemeVariant] yet — equivalent
  /// to `AppThemeVariant.modernBlue.light()`.
  static ThemeData light() => AppThemeVariant.modernBlue.light();

  /// Equivalent to `AppThemeVariant.modernBlue.dark()`.
  static ThemeData dark() => AppThemeVariant.modernBlue.dark();

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color surface,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required double cardRadius,
    required double inputRadius,
    required AppBrandColors brand,
    FontWeight headlineWeight = FontWeight.w700,
  }) {
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness, surface: surface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      cardColor: card,
      dividerColor: border,
      textTheme: _textTheme(textPrimary, textSecondary, headlineWeight),
      appBarTheme: AppBarTheme(backgroundColor: card, foregroundColor: textPrimary, elevation: 0, surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius), side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: BorderSide(color: border)),
      ),
      extensions: [brand],
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary, FontWeight headlineWeight) {
    return TextTheme(
      headlineSmall: TextStyle(fontWeight: headlineWeight, color: primary),
      titleLarge: TextStyle(fontWeight: headlineWeight, color: primary),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: primary),
      bodyLarge: TextStyle(color: primary),
      bodyMedium: TextStyle(color: secondary),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, color: primary),
    );
  }
}
