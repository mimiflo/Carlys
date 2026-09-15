import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/domain/usecases/record_planned_set.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';
import '../../support/in_memory_workout_template_repository.dart';

/// CE QUE CE FICHIER PROTÈGE : le CHEMIN emprunté, pas l'effet.
///
/// L'effet — série écrite, item de plan pointé — est déjà couvert de bout en
/// bout sur Drift réel par `session_plan_matching_test`. Ce qui peut
/// régresser sans qu'aucun de ces tests ne bronche, c'est le chemin : revenir
/// à « `addSet` puis `fulfillPlanItem` » depuis le cas d'usage redonnerait
/// exactement le même résultat visible, tout en rouvrant la fenêtre où une
/// application tuée entre les deux écritures laisse la série enregistrée et
/// la case du plan vide.
///
/// L'atomicité elle-même n'est PAS testée ici, et ne peut pas l'être :
/// `fulfillItem` est un simple UPDATE qui ne peut pas échouer, il n'existe
/// donc aucun point d'injection de panne entre les deux écritures. Elle
/// repose sur l'unique `db.transaction` de
/// `WorkoutTemplateRepositoryImpl.recordSetFulfillingPlan`, qui se vérifie à
/// la lecture. Écrire ici un test qui en aurait l'air sans l'être serait pire
/// que de ne rien écrire.
class _TemplatesEspion extends InMemoryWorkoutTemplateRepository {
  _TemplatesEspion(super.workouts);

  int viaCheminAtomique = 0;
  int viaPointageSepare = 0;

  @override
  Future<String> recordSetFulfillingPlan({
    required AddSetInput input,
    required String planItemId,
  }) {
    viaCheminAtomique += 1;
    return super.recordSetFulfillingPlan(input: input, planItemId: planItemId);
  }

  @override
  Future<void> fulfillPlanItem({
    required String planItemId,
    required String setId,
  }) {
    viaPointageSepare += 1;
    return super.fulfillPlanItem(planItemId: planItemId, setId: setId);
  }
}

void main() {
  late FakeWorkoutRepository workouts;
  late _TemplatesEspion templates;
  late RecordPlannedSet recordSet;

  setUp(() {
    workouts = FakeWorkoutRepository();
    templates = _TemplatesEspion(workouts);
    recordSet = RecordPlannedSet(workouts: workouts, templates: templates);
  });

  Future<String> lancerLeModele() async {
    final modeles = await templates.watchTemplates().first;
    return templates.startFromTemplate(modeles.first.id);
  }

  test(
    'une série qui honore une prévision passe par le chemin ATOMIQUE',
    () async {
      final sessionId = await lancerLeModele();
      final plan = await templates.sessionPlan(sessionId);
      final prevue = plan!.items.first;

      final enregistree = await recordSet(
        AddSetInput(
          sessionId: sessionId,
          exerciseId: prevue.exerciseId,
          exerciseName: prevue.exerciseName,
          reps: prevue.targetReps,
          weightKg: prevue.targetWeightKg,
        ),
      );

      expect(enregistree.fulfilled?.id, prevue.id);
      expect(
        templates.viaCheminAtomique,
        1,
        reason: 'le cas d’usage doit passer par recordSetFulfillingPlan',
      );
      // Le cas d'usage ne pointe plus l'item lui-même : c'est l'écriture unique
      // qui le fait, de l'intérieur. Un 2 ici signifierait un pointage séparé
      // rajouté par-dessus, donc la fenêtre rouverte.
      expect(templates.viaPointageSepare, 1);
    },
  );

  test('une série HORS plan n’emprunte pas ce chemin', () async {
    final sessionId = await lancerLeModele();

    final enregistree = await recordSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseName: 'Exercice hors programme',
        reps: 10,
      ),
    );

    expect(enregistree.fulfilled, isNull);
    expect(templates.viaCheminAtomique, 0);
    expect(templates.viaPointageSepare, 0);
    expect(workouts.addedSets, hasLength(1));
  });
}
