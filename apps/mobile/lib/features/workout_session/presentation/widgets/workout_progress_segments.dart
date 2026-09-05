import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Rangée de segments de progression : une barre par série de la séance.
///
/// Les séries enregistrées sont en accent, celle en cours de saisie en
/// primaire. Les séries **à venir** ne sont dessinées que lorsque la séance
/// suit un modèle : elles apparaissent alors en troisième tonalité (trait
/// sourd), une par série prévue restante. Sans modèle, [planned] vaut 0 et le
/// rendu est exactement celui d'avant — le domaine ne planifie rien de
/// lui-même.
class WorkoutProgressSegments extends StatelessWidget {
  const WorkoutProgressSegments({
    required this.completed,
    this.planned = 0,
    super.key,
  });

  /// Nombre de séries déjà enregistrées dans la séance.
  final int completed;

  /// Séries prévues encore à faire **après** celle en cours de saisie.
  final int planned;

  /// Géométrie de la maquette : segments de 4 de haut, espacés de 5.
  static const double _height = 4;
  static const double _gap = 5;

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
                      _ when index < completed => AppColors.accent,
                      _ when index < current => AppColors.primary,
                      _ => AppColors.difficultyTrack,
                    },
                    borderRadius: AppRadius.xsAll,
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
      return 'Progression de la séance : $done';
    }
    // Avec un modèle, la progression se lit par rapport au programme.
    final total = completed + upcoming + 1;
    return 'Progression de la séance : ${formatThousands(completed)} série'
        '${completed > 1 ? 's' : ''} sur ${formatThousands(total)} prévue'
        '${total > 1 ? 's' : ''}';
  }
}
