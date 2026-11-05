import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_professional.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';

/// A genuinely functional theme switch, same pattern as [LanguageSection]:
/// picking a card immediately changes the running app's `ThemeData` via
/// [themeVariantProvider], which `MaterialApp.router` watches directly. Both
/// themes stay available — "Modern Blue" is the original design and remains
/// the default; "Professional" is an added alternative, not a replacement.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeVariantProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text('Choose how the app looks.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final variant in AppThemeVariant.values)
                  _ThemeSwatchCard(
                    variant: variant,
                    isSelected: selected == variant,
                    onTap: () => ref.read(themeVariantProvider.notifier).setVariant(variant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatchCard extends StatelessWidget {
  const _ThemeSwatchCard({required this.variant, required this.isSelected, required this.onTap});

  final AppThemeVariant variant;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (sidebar, primary, surface) = switch (variant) {
      AppThemeVariant.modernBlue => (AppColors.sidebarNavy, AppColors.primaryBlue, AppColors.surfaceLight),
      AppThemeVariant.professional => (AppColorsProfessional.sidebarCharcoal, AppColorsProfessional.primaryEmerald, AppColorsProfessional.surfaceLight),
    };
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? scheme.primary : Theme.of(context).dividerColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MiniPreview(sidebar: sidebar, primary: primary, surface: surface),
                const Spacer(),
                if (isSelected) Icon(Icons.check_circle_rounded, color: scheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(variant.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A tiny stand-in dashboard: sidebar strip + a card with a primary-colored bar.
class _MiniPreview extends StatelessWidget {
  const _MiniPreview({required this.sidebar, required this.primary, required this.surface});
  final Color sidebar;
  final Color primary;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 60,
        height: 40,
        child: ColoredBox(
          color: surface,
          child: Row(
            children: [
              Container(width: 16, color: sidebar),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(3))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
