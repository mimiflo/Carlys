import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'exercise_picker_sheet.dart' show SetMeasure;

// Les deux commandes de la carte de saisie : la BASCULE d'unité et le
// bouton de validation.
//
// Extraits de la carte parce qu'ils ne décident rien — ils rendent un geste.
// La carte, elle, tient l'état de la saisie ; les mêler la faisait passer le
// plafond de 250 lignes du dépôt, et une carte de 330 lignes ne se relit plus
// d'un coup d'œil.

/// L'appel à l'action de la carte : valider la série saisie.
class SetValidateCta extends StatelessWidget {
  const SetValidateCta({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCtaButton(
      label: 'Valider la série',
      icon: AppIcons.check,
      onPressed: onPressed,
    );
  }
}

/// La bascule d'unité, discrète et toujours visible.
///
/// Elle ne se cache pas quand le catalogue a bien deviné : une bascule qui
/// n'apparaît que dans certains cas est une bascule qu'on cherche au moment
/// où on en a besoin. Elle reste petite parce que le défaut est bon la
/// plupart du temps.
class SetMeasureToggle extends StatelessWidget {
  const SetMeasureToggle({
    required this.measure,
    required this.onChange,
    super.key,
  });

  final SetMeasure measure;
  final ValueChanged<SetMeasure> onChange;

  @override
  Widget build(BuildContext context) {
    final versChrono = measure == SetMeasure.repsAndWeight;
    final label = versChrono
        ? 'Mesurer en temps et distance'
        : 'Mesurer en charge et répétitions';

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => onChange(
          versChrono ? SetMeasure.timeAndDistance : SetMeasure.repsAndWeight,
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkTextSecondary,
          textStyle: AppTypography.label,
        ),
        icon: const Icon(AppIcons.retry, size: 16),
        label: Text(label),
      ),
    );
  }
}
