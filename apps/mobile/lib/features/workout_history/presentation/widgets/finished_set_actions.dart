import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_session/presentation/utils/set_labels.dart';
import 'correct_set_sheet.dart';

/// Les deux gestes sur une série d'une séance TERMINÉE : la corriger, la
/// supprimer. Les records se recalculent à partir de ces séries : une charge
/// saisie 200 au lieu de 20 posait sinon un record faux et définitif.

Future<void> correctFinishedSet(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  required WorkoutSetEntry set,
}) async {
  final correction = await showCorrectSetSheet(context, set);
  if (correction == null || !context.mounted) {
    return;
  }
  await _write(
    context,
    () => ref
        .read(workoutActionsProvider)
        .correctSet(
          sessionId,
          set.id,
          reps: correction.reps,
          weightKg: correction.weightKg,
        ),
    success: 'Série corrigée.',
  );
}

Future<void> deleteFinishedSet(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  required WorkoutSetEntry set,
}) async {
  final confirmed = await showAppConfirm(
    context,
    title: 'Supprimer cette série ?',
    // La conséquence, pas seulement le geste : c'est ce qui distingue une
    // confirmation utile d'un « êtes-vous sûr » décoratif.
    message:
        '${set.exerciseName}, ${spokenSetValue(set)}. Tes records et tes '
        'statistiques seront recalculés sans elle.',
    confirmLabel: 'Supprimer',
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await _write(
    context,
    () => ref
        .read(workoutActionsProvider)
        .removeSetFromFinished(sessionId, set.id),
    success: 'Série supprimée.',
  );
}

/// L'écriture est LOCALE puis mise en file : elle aboutit hors ligne. Seule
/// une panne de la base locale peut échouer, et elle doit se voir.
Future<void> _write(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  final notices = AppNotices.of(context);
  try {
    await action();
    notices.show(success, tone: AppNoticeTone.success);
  } on AppException catch (error) {
    notices.show(error.message, tone: AppNoticeTone.error);
  }
}
