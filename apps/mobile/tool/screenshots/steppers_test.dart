// Captures des deux feuilles de SAISIE CHIFFRÉE — OUTIL, exécuté à la
// demande :
//   flutter test tool/screenshots/steppers_test.dart --update-goldens
//
// Comme les autres fichiers de ce dossier, il est HORS de `test/` : la CI ne
// compare jamais ces rendus, fragiles d'une version de moteur à l'autre, et
// les PNG sont ignorés par git.
//
// POURQUOI CE FICHIER EXISTE. La passe « le design system reprend ce qui lui
// appartient » (22 septembre 2026) a fait rejoindre aux `+` et `−` de ces
// deux feuilles la famille arrondie du reste de l'application : elles
// portaient `Icons.add` et `Icons.remove`, les variantes à angles vifs, quand
// tous les autres écrans portent `Icons.add_rounded`. C'était le seul
// changement VISIBLE de la passe — et il n'apparaissait dans AUCUNE capture :
// ces feuilles s'ouvrent par un geste, et la galerie ne montrait que les
// écrans qui les appellent.
//
// Un changement d'interface qu'aucune capture ne montre ne se relit pas. Ces
// deux vues comblent le trou, et resteront pour la prochaine fois.
//
// **Chaque feuille est posée sur SON écran, pas sur du noir.** Une feuille
// au-dessus du vide ne montre ni son voile, ni la part d'écran qu'elle laisse
// voir, ni si les deux vont ensemble — c'est-à-dire rien de ce qu'une
// relecture de capture doit juger. Le décor est donc fait des VRAIS widgets
// de chaque écran, nourris de faits plausibles.
//
// Et le déclencheur vit dans la barre basse, là où la feuille le recouvre :
// un bouton de harnais resté visible au milieu de l'écran se relirait comme
// un bouton du produit.
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/add_weight_sheet.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_weight_chart.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/exercise_set_row.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/set_input_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test.dart' show loadRealFonts;

/// Trois séries d'un développé couché ordinaire — montée en charge, puis
/// deux séries de travail. Des faits plausibles, jamais des valeurs rondes
/// de démonstration.
final List<WorkoutSetEntry> _series = [
  WorkoutSetEntry(
    id: 'serie-1',
    exerciseName: 'Développé couché',
    position: 0,
    kind: SetKind.warmup,
    completedAt: DateTime.utc(2026, 9, 22, 18, 12),
    syncState: LocalSyncState.synced,
    reps: 12,
    weightKg: 20,
  ),
  WorkoutSetEntry(
    id: 'serie-2',
    exerciseName: 'Développé couché',
    position: 1,
    kind: SetKind.normal,
    completedAt: DateTime.utc(2026, 9, 22, 18, 16),
    syncState: LocalSyncState.synced,
    reps: 10,
    weightKg: 42.5,
  ),
  WorkoutSetEntry(
    id: 'serie-3',
    exerciseName: 'Développé couché',
    position: 2,
    kind: SetKind.normal,
    completedAt: DateTime.utc(2026, 9, 22, 18, 20),
    syncState: LocalSyncState.synced,
    reps: 9,
    weightKg: 42.5,
  ),
];

/// Trois séries faites, la quatrième en attente : l'état exact d'une séance
/// au moment où l'on ouvre la feuille de saisie.
List<Widget> _decorSeance() => [
  for (final (index, serie) in _series.indexed)
    Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ExerciseSetRow(position: index + 1, set: serie),
    ),
  ExerciseSetRow(position: _series.length + 1),
];

/// La carte d'évolution du poids, telle que l'écran Progrès la met en tête :
/// la dernière pesée en grand, puis la courbe des précédentes. C'est le VRAI
/// widget de l'écran — une carte reconstruite à la main ne prouverait rien de
/// l'accord entre la feuille et ce qu'elle recouvre.
///
/// Les dates se comptent depuis MAINTENANT, parce que la carte les rend en
/// ÂGE : figées, elles feraient dire « il y a un an » à une capture
/// régénérée douze mois plus tard. C'est la règle des décors, apprise en
/// septembre 2026 — une date rendue à l'écran se date relativement à
/// maintenant.
List<Widget> _decorPoids() {
  // Une descente lente et crédible, du plus ancien au plus récent : ce que
  // huit semaines de travail donnent vraiment, pas une ligne droite.
  const poids = [77.8, 77.1, 76.9, 76.2, 75.8, 75.4, 75.1, 74.5];
  final maintenant = DateTime.now().toUtc();
  return [
    BodyWeightChart(
      entries: [
        for (final (index, valeur) in poids.indexed)
          BodyMetricEntry(
            id: 'pesee-$index',
            kind: BodyMetricKind.weightKg,
            value: valeur,
            measuredAt: maintenant.subtract(
              Duration(days: (poids.length - 1 - index) * 7 + 2),
            ),
          ),
      ],
    ),
  ];
}

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

  /// Ouvre la feuille par son geste réel, par-dessus le contenu qu'elle
  /// recouvre en vrai. Le geste est le seul chemin public vers ces
  /// formulaires, et il apporte le décor de la feuille — poignée, fond,
  /// arrondis, voile — que le formulaire monté seul n'aurait pas.
  Future<void> ouvre(
    WidgetTester tester, {
    required String titre,
    required String action,
    required List<Widget> decor,
    required Future<void> Function(BuildContext context) geste,
  }) async {
    telephone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(titre)),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: decor,
              ),
            ),
            // La barre basse de l'écran réel — et le déclencheur y vit, là
            // où la feuille le recouvrira.
            bottomNavigationBar: AppTranslucentBar(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppButton(
                    label: action,
                    onPressed: () => geste(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('la saisie d’une SÉRIE, avec ses deux pas', (tester) async {
    await ouvre(
      tester,
      titre: 'Développé couché',
      action: 'Ajouter une série',
      decor: _decorSeance(),
      geste: (context) async =>
          showSetInputSheet(context, exerciseName: 'Développé couché'),
    );

    expect(find.byIcon(AppIcons.add), findsWidgets);
    expect(find.byIcon(AppIcons.minus), findsWidgets);
    await capture(tester, 'pas-01-serie');
  });

  testWidgets('la saisie d’un POIDS, même grammaire', (tester) async {
    // La même paire de pas, sur l'autre feuille et un autre écran : c'est la
    // CONSTANCE entre les deux que la capture donne à relire, et c'est elle
    // qui manquait.
    await ouvre(
      tester,
      titre: 'Poids',
      action: 'Noter mon poids',
      decor: _decorPoids(),
      geste: (context) async => showAddWeightSheet(context, initialKg: 74.5),
    );

    expect(find.byIcon(AppIcons.add), findsWidgets);
    expect(find.byIcon(AppIcons.minus), findsWidgets);
    await capture(tester, 'pas-02-poids');
  });
}
