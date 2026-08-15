import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../settings/domain/app_theme_setting.dart';
import '../../../settings/presentation/controllers/theme_setting_controller.dart';

/// Groupe « PROFIL CARLYS » : l'identité choisie — jamais un niveau.
class ProfileIdentitySettings extends StatelessWidget {
  const ProfileIdentitySettings({
    required this.currentLabel,
    required this.onOpen,
    required this.onProgression,
    required this.onManifesto,
    this.titleLabel,
    super.key,
  });

  /// Titre du profil choisi (« Le Stratège »), `null` tant qu'aucun ne l'est.
  final String? currentLabel;

  /// Titre de progression atteint (« Artisan »), `null` tant que
  /// l'historique local n'est pas lu.
  final String? titleLabel;

  final VoidCallback onOpen;
  final VoidCallback onProgression;
  final VoidCallback onManifesto;

  @override
  Widget build(BuildContext context) {
    return AppSettingsGroup(
      label: 'Identité Carlys',
      rows: [
        AppSettingsRow(
          icon: AppIcons.carlysProfile,
          label: 'Mon profil',
          value: currentLabel ?? 'À choisir',
          onTap: onOpen,
        ),
        AppSettingsRow(
          icon: AppIcons.progress,
          label: 'Ma progression',
          // Aucune valeur tant que l'historique n'est pas lu : un tiret
          // vaut mieux qu'un titre provisoire qui changerait sous les yeux.
          value: titleLabel ?? '—',
          onTap: onProgression,
        ),
        AppSettingsRow(
          icon: AppIcons.brandAcademy,
          label: 'Le manifeste',
          onTap: onManifesto,
        ),
      ],
    );
  }
}

/// Groupe « ENTRAÎNEMENT ».
///
/// Les lignes « temps de repos par défaut » et « unités » de la maquette sont
/// absentes : aucun réglage correspondant n'existe dans le domaine.
class ProfileTrainingSettings extends StatelessWidget {
  const ProfileTrainingSettings({
    required this.goalLabel,
    required this.onGoal,
    required this.onTemplates,
    required this.onHistory,
    required this.onBodyMetrics,
    super.key,
  });

  /// Libellé de l'objectif nutritionnel courant, `null` s'il n'est pas défini.
  final String? goalLabel;
  final VoidCallback onGoal;

  /// Ouvre « Mes modèles » : gérer ses séances types est un réglage
  /// d'entraînement, pas un geste de démarrage.
  final VoidCallback onTemplates;
  final VoidCallback onHistory;
  final VoidCallback onBodyMetrics;

  @override
  Widget build(BuildContext context) {
    return AppSettingsGroup(
      label: 'Entraînement',
      rows: [
        AppSettingsRow(
          icon: AppIcons.goal,
          label: 'Objectif',
          value: goalLabel,
          onTap: onGoal,
        ),
        AppSettingsRow(
          icon: AppIcons.programs,
          label: 'Mes modèles de séance',
          onTap: onTemplates,
        ),
        AppSettingsRow(
          icon: AppIcons.history,
          label: 'Historique des séances',
          onTap: onHistory,
        ),
        AppSettingsRow(
          icon: AppIcons.bodyMetrics,
          label: 'Mesures corporelles',
          onTap: onBodyMetrics,
        ),
      ],
    );
  }
}

/// Groupe « APPLICATION ».
///
/// L'interrupteur bascule entre les thèmes clair et sombre ; la ligne elle-même
/// ouvre l'écran d'apparence, seul endroit où choisir « Système » ou
/// « Sombre OLED ». Les lignes « rappels de séance » et « exporter mes
/// données » de la maquette sont absentes : rien ne les alimente.
class ProfileAppSettings extends ConsumerWidget {
  const ProfileAppSettings({
    required this.onAppearance,
    required this.onDevices,
    super.key,
  });

  final VoidCallback onAppearance;
  final VoidCallback onDevices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(themeSettingProvider);
    final isDark = switch (setting) {
      AppThemeSetting.light => false,
      AppThemeSetting.dark || AppThemeSetting.oledDark => true,
      AppThemeSetting.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return AppSettingsGroup(
      label: 'Application',
      rows: [
        AppSettingsRow(
          icon: AppIcons.theme,
          label: 'Thème sombre',
          toggleValue: isDark,
          onToggle: (value) => ref.read(themeSettingProvider.notifier).setTheme(
                value ? AppThemeSetting.dark : AppThemeSetting.light,
              ),
          onTap: onAppearance,
        ),
        AppSettingsRow(
          icon: AppIcons.devices,
          label: 'Appareils connectés',
          onTap: onDevices,
        ),
      ],
    );
  }
}
