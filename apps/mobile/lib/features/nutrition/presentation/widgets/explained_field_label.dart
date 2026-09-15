import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/metric_explanation.dart';
import 'metric_explanation_sheet.dart';

/// Libellé de champ suivi de sa porte d'explication.
///
/// C'est le seul endroit de la fonctionnalité où le glyphe EST le bouton, et
/// c'est justifié : un libellé de champ ne fait que vingt points de haut et
/// n'a rien à ouvrir par lui-même — le rendre tapable ferait concurrence au
/// champ qu'il annonce.
///
/// C'est aussi l'endroit où le pourquoi compte le plus. Le niveau d'activité
/// et le plan sont les deux SEULES entrées que l'utilisateur choisit
/// librement, et ce sont elles qui déplacent tous les chiffres de l'écran :
/// les expliquer au moment du choix vaut mieux qu'après coup, quand le
/// résultat surprend.
class ExplainedFieldLabel extends StatelessWidget {
  const ExplainedFieldLabel({
    required this.label,
    required this.explication,
    super.key,
  });

  final String label;
  final MetricExplanation explication;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        AppExplainButton(
          aProposDe: explication.titre,
          onPressed: () => showMetricExplanation(context, explication),
        ),
      ],
    );
  }
}
