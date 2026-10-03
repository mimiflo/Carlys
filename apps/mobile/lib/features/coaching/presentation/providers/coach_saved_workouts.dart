import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../workout_template/presentation/providers/workout_template_providers.dart';
import '../controllers/coach_controllers.dart';

const _logger = AppLogger('CoachSavedWorkouts');

/// Les séances que le coach garde (« Mes modèles », catégorie Coach) naissent
/// côté serveur : dès qu'une réponse en apporte une, les modèles se
/// rapatrient, pour qu'elle soit sur l'appareil — hors ligne compris — sans
/// attendre le prochain lancement.
///
/// À appeler dans `build` : `ref.listen` s'y désabonne de lui-même.
void keepCoachWorkoutsOnDevice(WidgetRef ref) {
  ref.listen(coachThreadProvider, (previous, next) {
    final before = previous?.valueOrNull?.conversation.messages;
    final after = next.valueOrNull?.conversation.messages;
    // Le fil qui s'ouvre n'apporte rien de neuf : ses séances sont déjà
    // passées par un rapatriement.
    if (before == null || after == null || after.length <= before.length) {
      return;
    }
    if (!after.skip(before.length).any((m) => m.createdWorkout != null)) {
      return;
    }
    unawaited(
      ref
          .read(workoutTemplateActionsProvider)
          .refresh()
          .catchError(
            (Object error) => _logger.warning(
              'Séance du coach pas encore rapatriée',
              error: error,
            ),
          ),
    );
  });
}
