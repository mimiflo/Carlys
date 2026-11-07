import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../providers/today_metrics.dart';
import 'today_cell.dart';

/// AUJOURD'HUI : quatre mesures dans UNE surface.
///
/// Les filets en croix naissent d'un espacement d'un point sur un fond clair,
/// pas de bordures dessinées : quatre tuiles bordées chacune donnaient quatre
/// îlots posés sur le fond, là où il n'y a qu'un seul état du jour.
///
/// Chaque cellule dit ce qui est fait, ce qui était visé et ce qu'il reste.
/// La valeur seule ne vaut rien : « 654 kcal » n'est ni bon ni mauvais tant
/// qu'on ignore la cible.
class TodayGrid extends StatelessWidget {
  const TodayGrid({
    required this.metrics,
    this.steps,
    this.onOpenHydration,
    this.onAddMeal,
    super.key,
  });

  final List<TodayMetric> metrics;

  /// Les pas du jour, en rangée pleine largeur SOUS les quatre cellules —
  /// `null` sans santé connectée, et la grille reste celle d'avant. Une
  /// cinquième cellule aurait cassé le 2 × 2 ; une rangée s'y ajoute sans
  /// rien déplacer. Sans geste : les pas se comptent en marchant.
  final TodayMetric? steps;

  /// Ouvre la feuille d'hydratation.
  final VoidCallback? onOpenHydration;

  /// Ouvre l'écran d'ajout d'un repas.
  ///
  /// DEUX mesures se nourrissent donc depuis l'accueil, et les deux pour la
  /// même raison : boire et manger se décident plusieurs fois par jour, là
  /// où les séances et le poids ont leur propre moment. Ce sont aussi les
  /// deux seules dont le chiffre du jour reste faux tant qu'on n'a pas
  /// ouvert un autre onglet — la tuile montrait le manque sans offrir de le
  /// combler. Les deux autres cellules viennent des séances et n'ont
  /// toujours aucun geste : leur en donner un ferait croire le contraire.
  final VoidCallback? onAddMeal;

  /// Épaisseur du filet interne — c'est l'espacement qui le dessine.
  static const double _rule = 1;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.listRow),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Padding(
          // Deux points de marge : la bordure extérieure ne doit pas se
          // confondre avec les filets internes.
          padding: const EdgeInsets.all(2),
          child: ColoredBox(
            color: AppColors.gridRule,
            child: Column(
              children: [
                for (var row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: _rule),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _cell(metrics[row * 2])),
                        const SizedBox(width: _rule),
                        Expanded(child: _cell(metrics[row * 2 + 1])),
                      ],
                    ),
                  ),
                ],
                if (steps case final walked?) ...[
                  const SizedBox(height: _rule),
                  SizedBox(width: double.infinity, child: _cell(walked)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  TodayCell _cell(TodayMetric metric) => TodayCell(
    metric: metric,
    onTap: switch (metric.kind) {
      TodayMetricKind.hydratation => onOpenHydration,
      TodayMetricKind.calories => onAddMeal,
      _ => null,
    },
  );
}
