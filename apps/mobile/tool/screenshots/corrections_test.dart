// Captures des deux tranches livrées le 16 septembre 2026 — OUTIL, exécuté à
// la demande :
//   flutter test tool/screenshots/corrections_test.dart --update-goldens
//
// Comme les autres fichiers de ce dossier, il est HORS de test/ : la CI ne
// compare jamais ces rendus, fragiles entre versions de moteur, et les PNG
// sont ignorés par git.
//
// Les deux sujets sont des ÉTATS RARES, qu'une capture de l'application
// normale ne montrerait jamais : une cible calorique tombée sous le plancher
// de sécurité, et une série d'une séance terminée qu'on vient corriger. Les
// données d'exemple vivent donc ici, jamais dans `lib/`.
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/nutrition_explanations.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/metabolism_view.dart';
import 'package:carlys_mobile/features/workout_history/presentation/widgets/finished_set_row.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test.dart' show loadRealFonts;

/// Le profil que le plancher rattrape : femme de 70 ans, 150 cm, 40 kg,
/// sédentaire, perte de gras. Le calcul rendait 843 kcal avant le correctif ;
/// le serveur sert 1200 et pose `targetKcalFloored`.
const MetabolismResult _releve = MetabolismResult(
  bmi: 17.8,
  bmiCategory: BmiCategory.underweight,
  bmrKcal: 827,
  tdeeKcal: 992,
  targetKcal: 1200,
  targetKcalFloored: true,
  proteinG: 80,
  fatG: 33,
  carbsG: 145,
  waterMl: 1400,
);

/// Le même écran pour un profil ordinaire : aucune mention, c'est le
/// contraste qui montre ce que le correctif ajoute.
const MetabolismResult _ordinaire = MetabolismResult(
  bmi: 24.7,
  bmiCategory: BmiCategory.normal,
  bmrKcal: 1782,
  tdeeKcal: 2759,
  targetKcal: 2345,
  proteinG: 128,
  fatG: 65,
  carbsG: 291,
  waterMl: 2800,
);

/// Une séance terminée dont la première série porte le zéro de trop : 200 kg
/// au lieu de 20, la saisie qui posait un record faux et définitif.
final List<WorkoutSetEntry> _series = [
  WorkoutSetEntry(
    id: 'set-fautif',
    exerciseName: 'Squat',
    position: 0,
    kind: SetKind.normal,
    completedAt: DateTime.utc(2026, 9, 15, 18, 20),
    syncState: LocalSyncState.synced,
    reps: 5,
    weightKg: 200,
    plannedReps: 5,
    plannedWeightKg: 20,
  ),
  WorkoutSetEntry(
    id: 'set-2',
    exerciseName: 'Squat',
    position: 1,
    kind: SetKind.normal,
    completedAt: DateTime.utc(2026, 9, 15, 18, 24),
    syncState: LocalSyncState.synced,
    reps: 5,
    weightKg: 20,
    plannedReps: 5,
    plannedWeightKg: 20,
  ),
  WorkoutSetEntry(
    id: 'set-3',
    exerciseName: 'Fentes',
    position: 2,
    kind: SetKind.normal,
    completedAt: DateTime.utc(2026, 9, 15, 18, 31),
    syncState: LocalSyncState.synced,
    reps: 12,
    weightKg: 16,
  ),
];

void main() {
  setUpAll(loadRealFonts);

  /// Le gabarit d'un téléphone, comme les autres captures du dossier.
  void telephone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  Future<void> pumpNutrition(
    WidgetTester tester,
    MetabolismResult metabolism,
  ) async {
    telephone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: MetabolismView(metabolism: metabolism),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('plancher — la mention paraît sous l’objectif', (tester) async {
    await pumpNutrition(tester, _releve);
    expect(find.text('Cible relevée au minimum de sécurité'), findsOneWidget);
    await capture(tester, 'plancher-01-mention');
  });

  testWidgets('plancher — un profil ordinaire n’affiche rien', (tester) async {
    await pumpNutrition(tester, _ordinaire);
    expect(find.text('Cible relevée au minimum de sécurité'), findsNothing);
    await capture(tester, 'plancher-02-sans-mention');
  });

  testWidgets('plancher — l’explication que la mention ouvre', (tester) async {
    await pumpNutrition(tester, _releve);
    await tester.tap(find.text('Cible relevée au minimum de sécurité'));
    await tester.pumpAndSettle();
    expect(
      find.text(NutritionExplanations.plancherCalorique.titre),
      findsWidgets,
    );
    await capture(tester, 'plancher-03-explication');
  });

  /// Les séries d'une séance terminée, telles que l'écran de détail les
  /// empile. On monte la LIGNE plutôt que l'écran entier : le geste part
  /// d'elle, et l'écran complet demanderait toute la pile de providers pour
  /// ne rien montrer de plus.
  Future<void> pumpSeries(WidgetTester tester) async {
    telephone(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Séance')),
            body: SafeArea(
              child: Builder(
                builder: (context) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(
                      'Séries',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final serie in _series)
                      FinishedSetRow(sessionId: 'seance', set: serie),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// La série fautive est la PREMIÈRE : deux lignes portent « Squat », et
  /// sans ce choix explicite le geste tomberait sur celle qui est juste.
  Finder serieFautive() => find.text('Squat').first;

  testWidgets('correction — les séries d’une séance terminée', (tester) async {
    await pumpSeries(tester);

    expect(find.text('5 × 200 kg'), findsOneWidget);
    await capture(tester, 'correction-01-series');
  });

  testWidgets('correction — la feuille s’ouvre pré-remplie', (tester) async {
    await pumpSeries(tester);
    await tester.tap(serieFautive());
    await tester.pumpAndSettle();

    expect(find.text('Corriger la série'), findsOneWidget);
    await capture(tester, 'correction-02-feuille');
  });

  testWidgets('correction — la suppression dit sa conséquence', (tester) async {
    await pumpSeries(tester);
    await tester.longPress(serieFautive());
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cette série ?'), findsOneWidget);
    await capture(tester, 'correction-03-suppression');
  });
}
