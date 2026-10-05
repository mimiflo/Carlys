import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Rangée de segments de progression : une barre par série de l'exercice en
/// cours.
///
/// Les séries enregistrées sont en violet plein, celle en cours de saisie en
/// violet clair. Les séries **à venir** ne sont dessinées que lorsque la
/// séance suit un modèle : elles apparaissent alors en trait sourd, une par
/// série prévue restante. Sans modèle, [planned] vaut 0 — le domaine ne
/// planifie rien de lui-même.
class WorkoutProgressSegments extends StatelessWidget {
  const WorkoutProgressSegments({
    required this.completed,
    this.planned = 0,
    super.key,
  });

  /// Nombre de séries déjà enregistrées sur l'exercice.
  final int completed;

  /// Séries prévues encore à faire **après** celle en cours de saisie.
  final int planned;

  /// Géométrie de la maquette : segments de 8 de haut, espacés de 8.
  static const double _height = 8;
  static const double _gap = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final upcoming = planned < 0 ? 0 : planned;
    final current = completed + 1; // la série en cours de saisie
    final total = current + upcoming;

    return Semantics(
      label: _label(upcoming),
      child: Row(
        children: [
          for (var index = 0; index < total; index++) ...[
            if (index > 0) const SizedBox(width: _gap),
            Expanded(
              child: SizedBox(
                height: _height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: switch (index) {
                      _ when index < completed => AppColors.primary,
                      _ when index < current => AppColors.primaryLight,
                      _ => AppColors.difficultyTrack,
                    },
                    borderRadius: AppRadius.fullAll,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _label(int upcoming) {
    final done =
        '${formatThousands(completed)} série'
        '${completed > 1 ? 's' : ''} enregistrée${completed > 1 ? 's' : ''}';
    if (upcoming == 0) {
      return 'Progression de l’exercice : $done';
    }
    // Le libellé décrit CE QUE LA RANGÉE DESSINE : l'enregistré, la saisie
    // en cours, le prévu restant. Annoncer « X sur TOTAL prévues » gonflait
    // le dénominateur d'une unité par série libre (l'enregistré compte
    // AUSSI les séries hors programme) — le constat de clôture, lui, disait
    // le vrai compte quelques minutes plus tard.
    return 'Progression de l’exercice : $done, une en saisie, '
        '${formatThousands(upcoming)} encore prévue${upcoming > 1 ? 's' : ''}';
  }
}
