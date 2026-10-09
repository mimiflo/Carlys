import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/academy_journey.dart';
import '../../domain/academy_progress.dart';
import 'academy_progress_card.dart';
import 'journey_entry_card.dart';

/// La vue d'ensemble de l'Academy, sous « Tous » : où en est la lecture,
/// puis le parcours guidé. Chacune attend ses faits : tant qu'ils ne sont
/// pas relus, la carte ne paraît pas plutôt que d'afficher des zéros.
class AcademyOverview extends StatelessWidget {
  const AcademyOverview({
    required this.progress,
    required this.journey,
    super.key,
  });

  final AcademyProgress? progress;
  final JourneyProgress? journey;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    final journey = this.journey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null) ...[
          AcademyProgressCard(progress: progress),
          const SizedBox(height: AppSpacing.gapRow),
        ],
        if (journey != null) ...[
          JourneyEntryCard(
            progress: journey,
            onOpen: () => context.push(AppRoutes.academyJourney),
            onResume: () {
              final courante = journey.etapeCourante;
              if (courante != null) {
                context.push(
                  AppRoutes.academyJourneyStage(academyJourney[courante].rang),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.gapRow),
        ],
      ],
    );
  }
}
