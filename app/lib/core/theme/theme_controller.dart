import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

/// The user's chosen visual theme — "Modern Blue" (default) or
/// "Professional". Same in-memory-only pattern as [localeProvider]: an
/// explicit session choice, not yet persisted across app restarts.
final themeVariantProvider = NotifierProvider<ThemeVariantController, AppThemeVariant>(ThemeVariantController.new);

class ThemeVariantController extends Notifier<AppThemeVariant> {
  @override
  AppThemeVariant build() => AppThemeVariant.modernBlue;

  void setVariant(AppThemeVariant variant) => state = variant;
}
