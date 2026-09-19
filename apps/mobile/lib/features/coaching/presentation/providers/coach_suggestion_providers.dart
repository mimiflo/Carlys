/// Amorces de conversation du coach — un provider DÉRIVÉ, sans Notifier.
///
/// Il vit hors de `controllers/` comme le veut la règle du dépôt : un fichier
/// de `controllers/` porte exactement un Notifier, les providers purement
/// dérivés se rangent ici. `coach_controllers.dart` le réexporte, pour que
/// l'écran et ses tests n'aient pas à changer d'import.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carlys_profile/presentation/controllers/carlys_profile_controllers.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_template/presentation/controllers/workout_template_controllers.dart';
import '../../domain/services/coach_suggestions.dart';

/// Amorces calculées depuis l'état réel de l'utilisateur.
///
/// Les trois sources sont déjà chargées par ailleurs (modèles en local,
/// records et poids en cache Riverpod) : la bande de puces n'ajoute aucun
/// appel réseau. Une source en échec ne fait pas échouer les autres — sans
/// donnée, il reste la puce générique.
final coachSuggestionsProvider = Provider.autoDispose<List<String>>((ref) {
  final templates = ref.watch(workoutTemplatesProvider).valueOrNull;
  final records = ref.watch(personalRecordsProvider).valueOrNull;
  final weights = ref.watch(bodyWeightMetricsProvider).valueOrNull;
  final history = ref.watch(workoutHistoryProvider).valueOrNull;

  final freshest = _freshestRecord(records);
  final now = DateTime.now().toUtc();

  return coachSuggestions(
    CoachContext(
      carlysProfile: ref.watch(currentCarlysProfileProvider),
      templateName: (templates == null || templates.isEmpty)
          ? null
          : templates.first.name,
      recordExerciseName: freshest?.exerciseName,
      recordAgeDays: freshest == null
          ? null
          : now.difference(freshest.achievedAt).inDays,
      weightTrendKg: _weightTrend(weights),
      hasHistory: history != null && history.isNotEmpty,
    ),
  );
});

PersonalRecordEntry? _freshestRecord(List<PersonalRecordEntry>? records) {
  if (records == null || records.isEmpty) return null;
  return records.reduce(
    (best, entry) => entry.achievedAt.isAfter(best.achievedAt) ? entry : best,
  );
}

/// Écart entre la dernière mesure et la précédente. `null` en deçà de deux
/// mesures : une seule pesée ne fait pas une tendance.
double? _weightTrend(List<BodyMetricEntry>? weights) {
  if (weights == null || weights.length < 2) return null;
  return weights.last.value - weights[weights.length - 2].value;
}
