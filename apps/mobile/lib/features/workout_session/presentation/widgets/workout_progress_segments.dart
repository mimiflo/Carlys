import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Rangée de segments de progression : une barre par série de la séance.
///
/// Les séries enregistrées sont en accent, celle en cours de saisie en
/// primaire. Aucune série « à venir » n'est dessinée : le domaine ne
/// planifie pas les séries d'avance.
class WorkoutProgressSegments extends StatelessWidget {
  const WorkoutProgressSegments({required this.completed, super.key});

  /// Nombre de séries déjà enregistrées dans la séance.
  final int completed;

  /// Géométrie de la maquette : segments de 4 de haut, espacés de 5.
  static const double _height = 4;
  static const double _gap = 5;

  @override
  Widget build(BuildContext context) {
    final total = completed + 1; // la série en cours de saisie

    return Semantics(
      label: 'Progression de la séance : '
          '${formatThousands(completed)} série'
          '${completed > 1 ? 's' : ''} enregistrée'
          '${completed > 1 ? 's' : ''}',
      child: Row(
        children: [
          for (var index = 0; index < total; index++) ...[
            if (index > 0) const SizedBox(width: _gap),
            Expanded(
              child: SizedBox(
                height: _height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: index < completed
                        ? AppColors.accent
                        : AppColors.primary,
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
}
