import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/active_workout_choices.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/exercise_picker_sheet.dart';
import 'package:carlys_mobile/features/workout_template/presentation/controllers/session_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE LA SÉANCE ACTIVE DÉDUIT, vérifié sans monter un écran.
///
/// Ces deux fonctions ont été sorties du corps de la séance en promettant
/// qu'elles « se lisent et se vérifient sans monter un écran ». Elles n'étaient
/// pourtant couvertes qu'indirectement, par le déroulé complet d'une séance
/// issue d'un modèle — qui n'atteint ni le repli sur la dernière série
/// enregistrée, ni le repos par défaut. Ce fichier tient la promesse : aucun
/// widget, aucun conteneur, juste des entrées et des sorties.
void main() {
  /// Une série enregistrée, réduite à ce dont ces décisions dépendent.
  WorkoutSetEntry set(
    String exerciseName, {
    String? exerciseId,
    int? restSeconds,
    int position = 1,
  }) {
    return WorkoutSetEntry(
      id: 'set-$position',
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      position: position,
      kind: SetKind.normal,
      restSeconds: restSeconds,
      completedAt: DateTime.utc(2026, 1, 5),
      syncState: LocalSyncState.pending,
    );
  }

  /// Ce que le programme propose. [exerciseName] nul = programme terminé :
  /// la séance continue alors librement, ce n'est pas une erreur.
  SessionGuidance guidance({String? exerciseName, String? exerciseId}) {
    return SessionGuidance(
      templateName: 'Push force',
      doneCount: 1,
      totalCount: 4,
      upcomingInSession: 3,
      upcomingInExercise: 1,
      exerciseName: exerciseName,
      exerciseId: exerciseId,
    );
  }

  group('exercice en cours', () {
    test('un choix explicite passe AVANT le programme et l’historique', () {
      // La personne a le dernier mot : elle vient de choisir au catalogue,
      // le programme et les séries déjà faites ne doivent pas la contredire.
      const picked = PickedExercise(name: 'Rowing', exerciseId: 'ex-rowing');

      final choice = currentExercise(
        sets: [set('Développé couché', exerciseId: 'ex-dc')],
        guidance: guidance(exerciseName: 'Squat', exerciseId: 'ex-squat'),
        picked: picked,
      );

      expect(choice, same(picked));
    });

    test('sans choix explicite, c’est le programme qui propose', () {
      // Et il l’emporte sur la dernière série : c’est lui qui sait ce qui
      // vient ensuite, l’historique ne sait que ce qui vient d’être fait.
      final choice = currentExercise(
        sets: [set('Développé couché', exerciseId: 'ex-dc')],
        guidance: guidance(exerciseName: 'Squat', exerciseId: 'ex-squat'),
        picked: null,
      );

      expect(choice?.name, 'Squat');
      expect(choice?.exerciseId, 'ex-squat');
    });

    test('programme terminé : on reste sur la DERNIÈRE série enregistrée', () {
      // Le programme est épuisé (`exerciseName` nul) mais la séance continue
      // librement : l’exercice en cours est celui de la dernière série, pas
      // celui de la première.
      final choice = currentExercise(
        sets: [
          set('Développé couché', exerciseId: 'ex-dc', position: 1),
          set('Écarté poulie', exerciseId: 'ex-ep', position: 2),
        ],
        guidance: guidance(),
        picked: null,
      );

      expect(choice?.name, 'Écarté poulie');
      expect(choice?.exerciseId, 'ex-ep');
    });

    test('séance libre : la dernière série suffit, sans programme', () {
      // Aucun modèle lancé : `guidance` est nul, et rien ne doit planter.
      final choice = currentExercise(
        sets: [set('Traction', exerciseId: 'ex-trac')],
        guidance: null,
        picked: null,
      );

      expect(choice?.name, 'Traction');
      expect(choice?.exerciseId, 'ex-trac');
    });

    test('séance vierge : personne ne peut deviner, et c’est ainsi', () {
      // Aucune série, aucun programme, aucun choix : l’écran doit inviter à
      // choisir plutôt qu’inventer un exercice.
      final choice = currentExercise(
        sets: const [],
        guidance: null,
        picked: null,
      );

      expect(choice, isNull);
    });
  });

  group('repos annoncé', () {
    test('le dernier repos RÉELLEMENT saisi, en remontant le temps', () {
      // Le parcours est inverse et saute les séries sans repos : une série
      // récente qui n’en porte pas ne doit pas effacer celui d’avant.
      final rest = lastRestSeconds([
        set('Développé couché', restSeconds: 120, position: 1),
        set('Développé couché', restSeconds: 150, position: 2),
        set('Développé couché', position: 3),
      ]);

      expect(rest, 150);
    });

    test('aucune série : le repos type de 90 s', () {
      // Première série de l’exercice : rien à reprendre.
      expect(lastRestSeconds(const []), 90);
      expect(defaultRestSeconds, 90);
    });

    test('des séries, mais aucune n’a noté son repos : 90 s aussi', () {
      // Le repos est facultatif à la saisie ; une liste pleine de nuls doit
      // retomber sur la même valeur qu’une liste vide.
      final rest = lastRestSeconds([
        set('Squat', position: 1),
        set('Squat', position: 2),
      ]);

      expect(rest, defaultRestSeconds);
    });
  });
}
