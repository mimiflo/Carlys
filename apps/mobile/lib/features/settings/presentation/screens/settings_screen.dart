import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/app_theme_setting.dart';
import '../controllers/theme_setting_controller.dart';

/// Réglages de l'application — préférences locales, aucune donnée serveur.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(themeSettingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Apparence', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Le mode sombre OLED utilise un fond noir pur, économe sur '
              'les écrans OLED.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: RadioGroup<AppThemeSetting>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeSettingProvider.notifier).setTheme(value);
                  }
                },
                child: Column(
                  children: [
                    for (final setting in AppThemeSetting.values)
                      RadioListTile<AppThemeSetting>(
                        title: Text(setting.label),
                        value: setting,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Accessibilité', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Carlys respecte la préférence système de réduction des '
              'animations : activez-la dans les réglages de votre appareil '
              'pour figer les animations décoratives.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
