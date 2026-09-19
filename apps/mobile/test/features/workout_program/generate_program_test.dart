import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/program_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/generate_program_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_program_repository.dart';

/// CE QUE CE FICHIER PROTÈGE : le bouton « Générer » ne promet rien qu'il ne
/// puisse tenir, et il DIT pourquoi il attend.
///
/// Un bouton actif sur un profil incomplet coûte un aller-retour réseau pour
/// n'obtenir qu'un refus, et la personne ne sait toujours pas quoi remplir.
/// Un bouton grisé SANS explication est pire : il a l'air cassé.
void main() {
  const complet = TrainingProfile(
    goal: TrainingGoal.muscleGain,
    experience: TrainingExperience.beginner,
    weeklySessionsTarget: 4,
    sessionMinutesTarget: 45,
    equipmentSlugs: ['poids-du-corps'],
  );

  Future<void> monter(
    WidgetTester tester,
    TrainingProfile profile, {
    FakeProgramRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programRepositoryProvider.overrideWithValue(
            repository ?? FakeProgramRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GenerateProgramCard(profile: profile),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('attend, et NOMME ce qui manque', (tester) async {
    await monter(
      tester,
      const TrainingProfile(
        goal: null,
        experience: null,
        weeklySessionsTarget: null,
        sessionMinutesTarget: null,
        equipmentSlugs: [],
      ),
    );

    expect(find.text('Il manque encore quelque chose'), findsOneWidget);
    // La phrase énumère les cinq réponses, dans l'ordre de l'écran : la
    // personne sait quoi faire sans avoir à deviner.
    expect(
      find.textContaining(
        'ton objectif, ton niveau, tes séances par semaine, la durée d’une '
        'séance et ton matériel',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ne nomme QUE ce qui manque vraiment', (tester) async {
    await monter(
      tester,
      const TrainingProfile(
        goal: TrainingGoal.marathon,
        experience: TrainingExperience.advanced,
        weeklySessionsTarget: 5,
        sessionMinutesTarget: 60,
        equipmentSlugs: [],
      ),
    );

    expect(find.textContaining('Renseigne ton matériel'), findsOneWidget);
  });

  testWidgets(
    'une liste de matériel VIDE bloque : elle n’est pas une réponse',
    (tester) async {
      // Le serveur tranche pareil, et pour la même raison : `[]` ne se
      // distingue pas de « je n'ai pas répondu ». Dire « je n'ai rien », c'est
      // cocher « Poids du corps ».
      await monter(
        tester,
        const TrainingProfile(
          goal: null,
          experience: null,
          weeklySessionsTarget: null,
          sessionMinutesTarget: null,
          equipmentSlugs: [],
        ),
      );
      final bouton = tester.widget<AppButton>(find.byType(AppButton));
      expect(bouton.onPressed, isNull);
    },
  );

  testWidgets('s’active dès que les cinq réponses sont là', (tester) async {
    await monter(tester, complet);

    expect(find.text('Tout est prêt'), findsOneWidget);
    final bouton = tester.widget<AppButton>(find.byType(AppButton));
    expect(bouton.onPressed, isNotNull);
  });

  testWidgets('engendre, puis montre ce que le serveur a dû céder', (
    tester,
  ) async {
    await monter(tester, complet, repository: FakeProgramRepository());

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    // Le plan…
    expect(find.text('Programme 8 semaines'), findsOneWidget);
    expect(find.textContaining('8 semaines'), findsWidgets);
    // …ET son explication. C'est tout l'intérêt du rapport : un programme
    // dont le dos reçoit six séries au lieu de neuf le DIT, plutôt que de
    // laisser la déception arriver trois semaines plus tard.
    expect(
      find.textContaining('« dos » reçoit 6 séries par semaine au lieu de 9'),
      findsOneWidget,
    );
  });

  testWidgets('affiche le refus du serveur tel qu’il est écrit', (
    tester,
  ) async {
    final repository = FakeProgramRepository()
      ..generationFailure = const ValidationException(
        'Complète ton profil d’entraînement avant de générer.',
      );
    await monter(tester, complet, repository: repository);

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    // Le message vient du serveur, qui seul connaît la règle violée : il
    // s'affiche TEL QUEL. Le réécrire ici le rendrait plus vague, et les deux
    // finiraient par se contredire.
    expect(
      find.text('Complète ton profil d’entraînement avant de générer.'),
      findsOneWidget,
    );
    // Et la feuille de rapport ne s'ouvre pas sur un échec.
    expect(find.text('Voir mon programme'), findsNothing);
  });
}
