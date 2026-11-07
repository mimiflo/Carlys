import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/health_connection.dart';
import '../providers/health_providers.dart';

/// Où l'on rend à Carlys les trois lectures, plateforme par plateforme.
String healthAccessPath() => healthPlatformName() == 'Apple Santé'
    ? 'ouvre Réglages › Santé › Accès aux données et appareils › Carlys, '
          'et active Pas, Poids et Masse grasse.'
    : 'ouvre Health Connect (sur Android 14 et plus : Paramètres › Health '
          'Connect), puis « Autorisations des applications » › Carlys, et '
          'autorise Pas, Poids et Masse grasse.';

/// Le refus, dit sur le moment : ce qui manque, et comment le rendre.
/// `true` si la personne veut redemander.
Future<bool> confirmHealthRetry(BuildContext context) => showAppConfirm(
  context,
  icon: AppIcons.healthBlocked,
  title: 'Accès refusé',
  message:
      'Carlys n’a pas reçu l’accès à tes pas, à ton poids et à ta masse '
      'grasse. Il ne lit que ces trois données, et n’écrit rien. Pour '
      'l’autoriser, ${healthAccessPath()}',
  confirmLabel: 'Réessayer',
  cancelLabel: 'Fermer',
);

/// Android 9 à 13 : Health Connect est une application à installer.
/// `true` si la personne veut l'installer.
Future<bool> confirmHealthConnectInstall(BuildContext context) =>
    showAppConfirm(
      context,
      icon: AppIcons.connectedHealth,
      title: 'Health Connect à installer',
      message:
          'Sur ce téléphone, Health Connect est une application à part : '
          'c’est là que ta balance et ton podomètre écrivent. Installe-la '
          'depuis le Play Store, puis reviens activer Santé connectée.',
      confirmLabel: 'Installer Health Connect',
      cancelLabel: 'Plus tard',
    );

/// L'objectif de pas, saisi entre ses bornes. `null` si la personne renonce.
Future<int?> promptStepsGoal(BuildContext context, int current) async {
  final raw = await showAppPrompt(
    context,
    title: 'Objectif de pas',
    message:
        'Par défaut ${formatThousands(HealthSettings.defaultStepsGoal)} : '
        'le seuil où le bénéfice de la marche commence à plafonner chez '
        'l’adulte.',
    initialValue: '$current',
    keyboardType: TextInputType.number,
    suffixText: 'pas',
    icon: AppIcons.steps,
    validator: (value) {
      final goal = int.tryParse(value.replaceAll(RegExp(r'\s'), ''));
      if (goal == null ||
          goal < HealthSettings.minStepsGoal ||
          goal > HealthSettings.maxStepsGoal) {
        return 'Entre ${formatThousands(HealthSettings.minStepsGoal)} et '
            '${formatThousands(HealthSettings.maxStepsGoal)} pas.';
      }
      return null;
    },
  );
  return raw == null ? null : int.tryParse(raw.replaceAll(RegExp(r'\s'), ''));
}
