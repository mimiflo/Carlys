import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/illustrated_banner.dart';
import '../../../../shared/widgets/summit_illustration.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../widgets/resume_workout_card.dart';
import '../widgets/training_space.dart';

/// Training — tout l'entraînement derrière une seule porte (maquette
/// d'octobre 2026).
///
/// Le hub ne refait aucun écran : il ORCHESTRE ceux qui existent — séances,
/// programmes, exercices, coach, historique. Une seule exception : la séance
/// en cours, qui a droit à sa carte d'appel quand elle existe, parce qu'y
/// retourner est l'action la plus probable de l'onglet.
class TrainingHubScreen extends ConsumerWidget {
  const TrainingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: ListView(
        // LE scrollable de la page : le tap sur la barre d'état iOS la remonte.
        primary: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          MediaQuery.paddingOf(context).top + AppSpacing.md,
          AppSpacing.md,
          bottomInset + AppSpacing.gapSection,
        ),
        children: [
          const AppScreenHeader(
            title: 'Training',
            tagline: 'Ton entraînement, ton rythme',
            showBack: false,
          ),
          const SizedBox(height: AppSpacing.md),
          if (active != null) ...[
            ResumeWorkoutCard(
              onResume: () => context.push(AppRoutes.activeWorkout),
            ),
            const SizedBox(height: AppSpacing.gapSection),
          ],
          Semantics(
            header: true,
            child: Text(
              'Ton espace training',
              style: AppTypography.heading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const TrainingSpace(),
          const SizedBox(height: AppSpacing.gapTile),
          const IllustratedBanner(
            title: 'Un effort aujourd’hui.',
            titleAccent: 'Un pas de plus demain.',
            summitShift: SummitIllustration.wideTextShift,
          ),
        ],
      ),
    );
  }
}
