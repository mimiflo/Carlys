import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/academy_journey.dart';

/// Les six étapes du parcours en pastilles reliées (maquette Academy
/// d'octobre 2026) : cochées une fois terminées, cerclée pour l'étape en
/// cours, éteintes au-delà. Rien n'est verrouillé — une pastille éteinte dit
/// « pas encore », jamais « interdit ».
class JourneyStepper extends StatelessWidget {
  const JourneyStepper({required this.progress, super.key});

  final JourneyProgress progress;

  static const double dotSize = 20;

  @override
  Widget build(BuildContext context) {
    final etapes = progress.parEtape;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (index, etape) in etapes.indexed) ...[
            if (index > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: etapes[index - 1].termine
                      ? AppColors.primaryLight
                      : AppColors.darkBorder,
                ),
              ),
            _Dot(done: etape.termine, current: index == progress.etapeCourante),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.current});

  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: JourneyStepper.dotSize,
      height: JourneyStepper.dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done ? AppColors.violetRamp : null,
        color: done ? null : AppColors.darkSurfaceAlt,
        border: done
            ? null
            : Border.all(
                color: current ? AppColors.primaryLight : AppColors.darkBorder,
                width: current ? 2 : 1,
              ),
      ),
      child: done
          ? const Icon(
              AppIcons.check,
              size: 12,
              color: AppColors.darkTextPrimary,
            )
          : current
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                ),
              ),
            )
          : null,
    );
  }
}
