import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/exercise_picker_sheet.dart'
    show SetMeasure;
import 'package:carlys_mobile/features/workout_session/presentation/widgets/set_entry_card.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/set_entry_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : une course ne se compte pas en répétitions, et
/// une planche ne se compte pas en kilos.
///
/// Le serveur et la base portaient `durationSeconds` et `distanceMeters`
/// depuis toujours ; l'application ne savait pas les SAISIR. Résultat : un
/// mouvement cardio s'enregistrait en « 20 kg × 10 reps », ce qui est une
/// mesure fausse, pas une mesure manquante — et elle partait dans les records
/// personnels, où le fait est dénormalisé et ne se rattrape plus.
void main() {
  Future<SetEntryValues?> monter(
    WidgetTester tester, {
    SetMeasure measure = SetMeasure.repsAndWeight,
    int? plannedDurationSeconds,
    WorkoutSetEntry? previous,
  }) async {
    SetEntryValues? valide;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SetEntryCard(
              setNumber: 1,
              previous: previous,
              measure: measure,
              plannedDurationSeconds: plannedDurationSeconds,
              onValidate: (values) => valide = values,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return valide;
  }

  testWidgets('un mouvement de force s’ouvre en charge et répétitions', (
    tester,
  ) async {
    await monter(tester);
    expect(find.text('CHARGE'), findsOneWidget);
    expect(find.text('RÉPÉTITIONS'), findsOneWidget);
    expect(find.text('DURÉE'), findsNothing);
  });

  testWidgets('un mouvement CARDIO s’ouvre en temps et distance', (
    tester,
  ) async {
    await monter(tester, measure: SetMeasure.timeAndDistance);
    expect(find.text('DURÉE'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);
    // Proposer une charge sur une course invite à saisir une donnée fausse.
    expect(find.text('CHARGE'), findsNothing);
  });

  testWidgets(
    'une cible chronométrée du programme l’emporte sur le catalogue',
    (tester) async {
      // Un gainage est classé RENFORCEMENT au catalogue et se prescrit pourtant
      // en secondes : c'est le plan qui sait, pas la taxonomie.
      await monter(
        tester,
        plannedDurationSeconds: 45,
        // measure reste la valeur par défaut, celle d'un mouvement de force.
      );
      expect(find.text('DURÉE'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
    },
  );

  testWidgets('la bascule change d’unité dans les deux sens', (tester) async {
    await monter(tester);
    expect(find.text('CHARGE'), findsOneWidget);

    await tester.tap(find.text('Mesurer en temps et distance'));
    await tester.pumpAndSettle();
    expect(find.text('DURÉE'), findsOneWidget);
    expect(find.text('CHARGE'), findsNothing);

    await tester.tap(find.text('Mesurer en charge et répétitions'));
    await tester.pumpAndSettle();
    expect(find.text('CHARGE'), findsOneWidget);
  });

  testWidgets('ne valide QUE le couple de l’unité choisie', (tester) async {
    SetEntryValues? valide;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SetEntryCard(
              setNumber: 1,
              previous: null,
              measure: SetMeasure.timeAndDistance,
              onValidate: (values) => valide = values,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider la série'));
    await tester.pumpAndSettle();

    expect(valide, isNotNull);
    expect(valide!.durationSeconds, isNotNull);
    // La charge et les répétitions restent NULLES : les envoyer aussi ferait
    // enregistrer « 20 kg » sur une course, parce que le formulaire les avait
    // en mémoire depuis son état initial.
    expect(valide!.weightKg, isNull);
    expect(valide!.reps, isNull);
    // Zéro mètre n'est pas une distance : un gainage ne va nulle part.
    expect(valide!.distanceMeters, isNull);
  });

  testWidgets('reprend la dernière performance chronométrée', (tester) async {
    await monter(
      tester,
      measure: SetMeasure.timeAndDistance,
      previous: WorkoutSetEntry(
        id: 'precedent',
        exerciseName: 'Course',
        position: 0,
        kind: SetKind.normal,
        durationSeconds: 600,
        distanceMeters: 2000,
        completedAt: DateTime.utc(2026, 9, 19),
        syncState: LocalSyncState.synced,
      ),
    );
    // Dix minutes se lisent « 10:00 », pas « 600 s ».
    expect(find.text('10:00'), findsOneWidget);
    // Deux mille mètres, avec l'espace fine du formateur du dépôt : on
    // compare à CE qu'il produit, pas à ce qu'on croit qu'il produit.
    expect(find.text(formatThousands(2000)), findsOneWidget);
  });

  group('la durée se lit dans l’unité qui la rend claire', () {
    test('sous la minute, des secondes', () {
      expect(formatDuration(45), (value: '45', unit: 's'));
    });

    test('au-delà, des minutes à deux chiffres', () {
      expect(formatDuration(60), (value: '1:00', unit: 'min'));
      expect(formatDuration(605), (value: '10:05', unit: 'min'));
    });
  });
}
