import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/presentation/utils/template_draft.dart';
import 'package:carlys_mobile/features/workout_template/presentation/widgets/planned_number_cell.dart';
import 'package:carlys_mobile/features/workout_template/presentation/widgets/planned_sets_table.dart';
import 'package:carlys_mobile/features/workout_template/presentation/widgets/set_kind_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le tableau des séries prévues de l'éditeur (maquette d'octobre 2026) :
/// la saisie se fait au clavier, dans les bornes partagées avec l'API.
void main() {
  late List<DraftSet> sets;

  Future<void> monter(
    WidgetTester tester, {
    List<DraftSet> initial = const [
      DraftSet(targetReps: 8, targetWeightKg: 80, restSeconds: 90),
      DraftSet(targetReps: 8, targetWeightKg: 80, restSeconds: 90),
    ],
  }) async {
    sets = initial;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                PlannedSetsTable(
                  exercise: DraftExercise(
                    localId: 'dc',
                    name: 'Développé couché',
                    sets: sets,
                  ),
                  onChangeSet: (index, set) =>
                      setState(() => sets = [...sets]..[index] = set),
                  onRemoveSet: (index) =>
                      setState(() => sets = [...sets]..removeAt(index)),
                ),
                SetKindSelector(
                  sets: sets,
                  onChoose: (kind) => setState(
                    () => sets = [for (final s in sets) s.copyWith(kind: kind)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Finder cell(String label) => find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );

  Finder field(String label) =>
      find.descendant(of: cell(label), matching: find.byType(TextField));

  testWidgets('la charge se tape, virgule comprise ; vide, elle se retire', (
    tester,
  ) async {
    await monter(tester);
    await tester.enterText(field('Charge de la série 1, en kilos'), '82,5');
    expect(sets.first.targetWeightKg, 82.5);

    await tester.enterText(field('Charge de la série 1, en kilos'), '');
    expect(sets.first.targetWeightKg, isNull);
    expect(sets.last.targetWeightKg, 80);
  });

  testWidgets('répétitions et repos restent dans les bornes de l’API', (
    tester,
  ) async {
    await monter(tester);
    await tester.enterText(field('Répétitions de la série 2'), '0');
    expect(sets.last.targetReps, 1);

    await tester.enterText(
      field('Repos après la série 2, en secondes'),
      '99999',
    );
    expect(sets.last.restSeconds, WorkoutTemplateLimits.restSecondsMax);
  });

  testWidgets('retirer une série remonte la suivante dans sa ligne', (
    tester,
  ) async {
    await monter(tester);
    await tester.enterText(field('Répétitions de la série 2'), '12');
    await tester.tap(find.byTooltip('Retirer la série 1'));
    await tester.pump();

    expect(sets, hasLength(1));
    expect(sets.single.targetReps, 12);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('« Type de série » change toutes les séries, le rang une seule', (
    tester,
  ) async {
    await monter(tester);
    expect(find.text('Série normale'), findsOneWidget);

    await tester.tap(find.text('Série normale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Échauffement'));
    await tester.pumpAndSettle();
    expect(sets.map((s) => s.kind), everyElement(SetKind.warmup));

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dégressive'));
    await tester.pumpAndSettle();
    expect(sets.map((s) => s.kind), [SetKind.warmup, SetKind.drop]);
    expect(find.text('Types mélangés'), findsOneWidget);
  });

  testWidgets('retirer une série pendant la saisie d’une autre : rien ne '
      's’écrase', (tester) async {
    await monter(
      tester,
      initial: const [
        DraftSet(targetReps: 1),
        DraftSet(targetReps: 2),
        DraftSet(targetReps: 3),
      ],
    );
    // La série 2 a le focus ; on retire la série 1 au-dessus d'elle.
    await tester.enterText(field('Répétitions de la série 2'), '22');
    await tester.tap(find.byTooltip('Retirer la série 1'));
    await tester.pump();

    expect(sets.map((s) => s.targetReps), [22, 3]);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('une troisième décimale est refusée à la frappe', (tester) async {
    await monter(tester);
    await tester.enterText(field('Charge de la série 1, en kilos'), '82,25');
    expect(sets.first.targetWeightKg, 82.25);
    await tester.enterText(field('Charge de la série 1, en kilos'), '82,255');
    expect(sets.first.targetWeightKg, 82.25);
  });

  testWidgets('les cases et le rang se touchent au doigt et à la voix', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await monter(tester);

    final rank = find.bySemanticsLabel(RegExp('^Série 1, série normale'));
    // Un bouton que le lecteur d'écran sait ACTIONNER : `excludeSemantics`
    // retirait l'action de l'InkWell, il faut la relayer.
    void actionnable(Finder finder) {
      final data = tester.getSemantics(finder).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    }

    actionnable(rank);
    actionnable(
      find.bySemanticsLabel(RegExp('^Type de série : Série normale')),
    );
    // Le libellé est porté par le champ réel, éditable.
    final charge = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Charge de la série 1')),
    );
    expect(charge.getSemanticsData().flagsCollection.isTextField, isTrue);

    expect(tester.getSize(rank).height, AppSpacing.touchTarget);
    // La case entière fait la cible, et le champ la remplit (bordure
    // comprise) : toucher son haut ou son bas donne aussi le focus.
    final box = find.byType(PlannedNumberCell).first;
    expect(tester.getSize(box).height, AppSpacing.touchTarget);
    expect(
      tester
          .getSize(find.descendant(of: box, matching: find.byType(TextField)))
          .height,
      greaterThanOrEqualTo(AppSpacing.touchTarget - 2),
    );
    semantics.dispose();
  });
}
