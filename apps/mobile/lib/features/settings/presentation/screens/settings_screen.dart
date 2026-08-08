import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/app_theme_setting.dart';
import '../controllers/theme_setting_controller.dart';

/// Apparence de l'application — préférence locale, aucune donnée serveur.
///
/// L'onglet Profil bascule clair/sombre d'un geste ; cet écran expose le choix
/// complet (Système, Sombre OLED).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeSettingProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('Apparence')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.gapSection,
          ),
          children: [
            const AppSectionLabel('Thème'),
            const SizedBox(height: AppSpacing.gapTile),
            for (final setting in AppThemeSetting.values) ...[
              _ThemeOption(
                setting: setting,
                selected: setting == selected,
                onTap: () =>
                    ref.read(themeSettingProvider.notifier).setTheme(setting),
              ),
              const SizedBox(height: AppSpacing.gapTile),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Le mode sombre OLED utilise un fond noir pur, économe sur les '
              'écrans OLED.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.gapSection),
            const AppSectionLabel('Accessibilité'),
            const SizedBox(height: AppSpacing.gapTile),
            Text(
              'Carlys respecte la préférence système de réduction des '
              'animations : activez-la dans les réglages de votre appareil '
              'pour figer les animations décoratives.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Option de thème : ligne de liste avec coche accent quand elle est active.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.setting,
    required this.selected,
    required this.onTap,
  });

  final AppThemeSetting setting;
  final bool selected;
  final VoidCallback onTap;

  /// Réserve la place de la coche pour aligner tous les libellés.
  static const double _checkSize = 20;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: AppListRow(
        title: setting.label,
        leading: AppIcons.theme,
        onTap: onTap,
        trailing: selected
            ? const Icon(
                AppIcons.check,
                size: _checkSize,
                color: AppColors.accent,
              )
            : const SizedBox(width: _checkSize, height: _checkSize),
      ),
    );
  }
}
