import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/server_gesture.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_template/presentation/providers/workout_template_providers.dart';
import 'today_workout_card.dart';

/// La séance du jour, branchée sur ses données.
///
/// À part de l'accueil pour une raison mesurée : la séance en cours change à
/// CHAQUE série validée, et l'accueil reste monté sous l'écran de séance.
/// Lue par l'écran entier, elle reconstruisait toute la liste dix fois pour
/// dix séries ; lue ici, seule la carte qui l'affiche se reconstruit
/// (`home_screen_test.dart`).
class HomeTodayWorkout extends ConsumerWidget {
  const HomeTodayWorkout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TodayWorkoutCard(
      activeWorkout: ref.watch(activeWorkoutProvider).valueOrNull,
      // Le NOMBRE de modèles, seul : une retouche d'un modèle ne change rien
      // à la carte.
      templateCount: ref.watch(
        workoutTemplatesProvider.select((async) => async.valueOrNull?.length),
      ),
      onOpenTemplates: () => context.push(AppRoutes.templates),
      onStart: () async {
        // Même règle, même endroit que la fiche d'exercice : la décision se
        // prend sur la BASE, et l'échec se dit. Ce bouton lisait
        // `activeWorkout`, c'est-à-dire le cache du provider, et appelait
        // `start()` sans filet — sur un cache en échec il partait ouvrir une
        // séance alors qu'une séance existait, et le `StateError` du domaine
        // le laissait sur place, sans message.
        final abouti = await runLocalGesture(
          context,
          ref.read(workoutActionsProvider).currentOrStart,
          scope: 'HomeScreen',
          echec: 'La séance n’a pas pu être ouverte. Réessaie.',
        );
        if (abouti && context.mounted) {
          await context.push(AppRoutes.activeWorkout);
        }
      },
    );
  }
}
