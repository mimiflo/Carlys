import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progress/data/dto/progress_dtos.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/utils/progress_stats.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/add_measurement_sheet.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_measurements_section.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_metric_chart.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/progress_first_steps.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/timeline_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_contract.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/first_run_prefs.dart';
import 'progress_flow_test.dart' show appWith, openProgressTab, reveal;

/// LES MENSURATIONS : sept tours, en cm, dans la même table que le poids.
///
/// Ce que ce fichier protège : qu'une zone se saisisse, se lise (dernière
/// valeur et écart depuis la première), se corrige et se supprime comme une
/// pesée — et qu'elle ne se CONFONDE jamais avec une pesée : ni dans la
/// confirmation de suppression (une mensuration ne déplace pas la cible
/// calorique), ni dans la frise.
void main() {
  BodyMetricEntry tour(
    BodyMetricKind kind,
    double value,
    int joursAvant, {
    String? id,
  }) => BodyMetricEntry(
    id: id ?? '${kind.apiValue}-$joursAvant',
    kind: kind,
    value: value,
    measuredAt: DateTime.now().toUtc().subtract(Duration(days: joursAvant)),
  );

  group('domaine', () {
    test('types et bornes sont ceux du contrat de l’API', () {
      // Lus dans `packages/api-contracts/src/progress.ts`, jamais recopiés :
      // la feuille refuse avant l'envoi ce que le serveur refuserait après.
      final types = contractStrings(
        'progress.ts',
        RegExp(r'bodyMetricTypeSchema = z\.enum\(\[([\s\S]*?)\]\)'),
      );
      expect(BodyMetricKind.values.map((k) => k.apiValue), types);

      final bornes = {
        for (final m in RegExp(
          r'(\w+): \{ min: ([\d.]+), max: ([\d.]+), decimals: (\d+) \}',
        ).allMatches(contractSource('progress.ts')))
          m.group(1)!: (
            double.parse(m.group(2)!),
            double.parse(m.group(3)!),
            int.parse(m.group(4)!),
          ),
      };
      expect(bornes.keys, types, reason: 'BODY_METRIC_BOUNDS illisible');
      expect({
        for (final kind in BodyMetricKind.values)
          kind.apiValue: (kind.min, kind.max, kind.decimals),
      }, bornes);
      expect(BodyMetricKind.measurements.every((k) => k.unit == 'cm'), isTrue);
      expect(BodyMetricKind.weightKg.isMeasurement, isFalse);
    });

    test('un type inconnu ne devient pas un poids', () {
      expect(BodyMetricKind.tryFromApi('WAIST_CM'), BodyMetricKind.waistCm);
      expect(BodyMetricKind.tryFromApi('WRIST_CM'), isNull);
      // Le DTO décide : une réponse au type inconnu est illisible.
      expect(
        () => bodyMetricFromJson({
          'id': 'm-1',
          'metricType': 'WRIST_CM',
          'value': 17,
          'measuredAt': '2026-11-02T08:00:00.000Z',
        }),
        throwsFormatException,
      );
    });

    test('l’écart se dit depuis la première mesure, au dixième', () {
      final premiere = tour(BodyMetricKind.waistCm, 85, 30);
      final depuis = 'depuis le ${formatDayMonth(premiere.measuredAt)}';
      expect(
        measurementTrend([premiere]),
        'Première mesure · ${formatDayMonth(premiere.measuredAt)}',
      );
      expect(
        measurementTrend([premiere, tour(BodyMetricKind.waistCm, 81.5, 1)]),
        '−3,5 cm $depuis',
      );
      // 82,3 − 80,1 vaut 2,1999… en flottants : il s'écrit 2,2.
      final bras = tour(BodyMetricKind.armCm, 80.1, 30);
      expect(
        measurementTrend([bras, tour(BodyMetricKind.armCm, 82.3, 1)]),
        '+2,2 cm depuis le ${formatDayMonth(bras.measuredAt)}',
      );
      expect(
        measurementTrend([premiere, tour(BodyMetricKind.waistCm, 85, 1)]),
        'Stable $depuis',
      );
    });
  });

  group('lecteur d’écran', () {
    Future<SemanticsNode> courbe(
      WidgetTester tester,
      List<BodyMetricEntry> entries,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: BodyMetricChart(entries: entries)),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSemantics(find.byType(RepaintBoundary).last);
    }

    testWidgets('la courbe du poids se dit comme avant, en kilos', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final noeud = await courbe(tester, [
        tour(BodyMetricKind.weightKg, 80, 10),
        tour(BodyMetricKind.weightKg, 78, 1),
      ]);
      expect(
        noeud.label,
        'Évolution du poids corporel, de 80 à 78 kilos sur 2 mesures',
      );
      semantics.dispose();
    });

    testWidgets('celle d’une zone se dit en centimètres', (tester) async {
      final semantics = tester.ensureSemantics();
      final noeud = await courbe(tester, [
        tour(BodyMetricKind.waistCm, 85, 10),
        tour(BodyMetricKind.waistCm, 81.5, 1),
      ]);
      expect(
        noeud.label,
        'Évolution : tour de taille, de 85 à 81,5 centimètres sur 2 mesures',
      );
      semantics.dispose();
    });

    test('chaque unité a sa forme parlée', () {
      expect(BodyMetricKind.weightKg.spokenUnit, 'kilos');
      expect(BodyMetricKind.bodyFatPercent.spokenUnit, 'pour cent');
      expect(BodyMetricKind.armCm.spokenUnit, 'centimètres');
    });
  });

  group('feuille de saisie', () {
    testWidgets('corriger une mesure de plus de deux ans ouvre le calendrier', (
      tester,
    ) async {
      final ancienne = DateTime.now().subtract(const Duration(days: 365 * 3));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAddMeasurementSheet(
                  context,
                  initialKind: BodyMetricKind.waistCm,
                  initialValue: 90,
                  initialDate: ancienne,
                  correction: true,
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      // Le calendrier refusait de s'ouvrir sur une date antérieure à sa
      // première date permise (`initialDate >= firstDate`).
      await tester.tap(find.text('Date de la mesure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('timeline', () {
    Future<void> ligne(WidgetTester tester, String type, num value) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: TimelineRow(
                event: ProgressEvent(
                  id: 'MEASURE:1',
                  kind: ProgressEventKind.measure,
                  occurredAt: DateTime.utc(2026, 11, 2, 8),
                  payload: {'metricType': type, 'value': value},
                ),
              ),
            ),
          ),
        );

    testWidgets('un tour de taille se lit comme tel, en cm', (tester) async {
      await ligne(tester, 'WAIST_CM', 82.5);
      expect(find.text('Tour de taille'), findsOneWidget);
      expect(find.textContaining('82,5 cm'), findsOneWidget);
      expect(find.text('Pesée'), findsNothing);
    });

    testWidgets('un type inconnu reste une mesure, sans unité', (tester) async {
      await ligne(tester, 'WRIST_CM', 17);
      expect(find.text('Mesure'), findsOneWidget);
      expect(find.textContaining('kg'), findsNothing);
    });
  });

  group('écran Progrès', () {
    setUp(() {
      seedCompletedFirstRun();
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures.allOn;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    Future<void> ouvrir(
      WidgetTester tester,
      FakeProgressRepository progress,
    ) async {
      await tester.pumpWidget(appWith(progress));
      await tester.pumpAndSettle();
      await openProgressTab(tester);
    }

    Finder dansLaSection(Finder cible) => find.descendant(
      of: find.byType(BodyMeasurementsSection),
      matching: cible,
    );

    testWidgets(
      'vide, la section invite ; la saisie refuse l’invraisemblable',
      (tester) async {
        // Un poids, pour que l'écran ne soit pas celui du premier jour.
        final progress = FakeProgressRepository(
          bodyMetrics: [tour(BodyMetricKind.weightKg, 80, 2)],
        );
        await ouvrir(tester, progress);

        await reveal(tester, find.text('Aucune mensuration'));
        await tester.tap(dansLaSection(find.text('Prendre une mesure')));
        await tester.pumpAndSettle();

        // Aujourd'hui par défaut.
        expect(find.text('Date de la mesure'), findsOneWidget);
        await tester.tap(find.text('Bras'));
        await tester.pumpAndSettle();
        final champ = find.byType(TextField);
        final enregistrer = find.widgetWithText(AppButton, 'Enregistrer');

        // 150 cm est un tour de taille possible, pas un tour de bras.
        await tester.enterText(champ, '150');
        await tester.pump();
        expect(find.text('Entre 10 et 100 cm.'), findsOneWidget);
        expect(tester.widget<AppButton>(enregistrer).onPressed, isNull);

        await tester.enterText(champ, '36,55');
        await tester.pump();
        expect(find.textContaining('Une décimale au plus'), findsOneWidget);

        await tester.enterText(champ, '36,5');
        await tester.pump();
        await tester.tap(enregistrer);
        await tester.pumpAndSettle();

        final enregistree = (await progress.bodyMetrics(
          kind: BodyMetricKind.armCm,
        )).single;
        expect(enregistree.value, 36.5);
        await reveal(tester, dansLaSection(find.text('Bras')));
        expect(dansLaSection(find.text('36,5 cm')), findsOneWidget);
        expect(
          dansLaSection(find.textContaining('PREMIÈRE MESURE')),
          findsOneWidget,
        );
        expect(find.text('Aucune mensuration'), findsNothing);
      },
    );

    testWidgets('une zone : dernière valeur, écart, courbe et correction', (
      tester,
    ) async {
      final progress = FakeProgressRepository(
        bodyMetrics: [
          tour(BodyMetricKind.weightKg, 80, 2),
          tour(BodyMetricKind.waistCm, 85, 30, id: 'taille-1'),
          tour(BodyMetricKind.waistCm, 81.5, 1, id: 'taille-2'),
          tour(BodyMetricKind.neckCm, 39, 3),
        ],
      );
      await ouvrir(tester, progress);

      await reveal(tester, dansLaSection(find.text('Tour de taille')));
      expect(dansLaSection(find.text('81,5 cm')), findsOneWidget);
      expect(
        dansLaSection(find.textContaining('−3,5 CM DEPUIS')),
        findsOneWidget,
      );
      // Les zones jamais mesurées n'ont pas de ligne.
      expect(dansLaSection(find.text('Cou')), findsOneWidget);
      expect(dansLaSection(find.text('Mollet')), findsNothing);

      await tester.tap(dansLaSection(find.text('Tour de taille')));
      await tester.pumpAndSettle();
      expect(find.text('Tour de taille · 2 mesures'), findsOneWidget);
      // La courbe du poids, reprise pour la zone.
      expect(find.byType(BodyMetricChart), findsWidgets);

      // Supprimer une mensuration ne parle pas de cible calorique.
      final feuille = find.byType(ListView).last;
      await tester.tap(
        find
            .descendant(of: feuille, matching: find.byIcon(AppIcons.delete))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ta cible calorique'), findsNothing);
      expect(find.textContaining('disparaîtra de ta courbe'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(progress.removedMetricIds, isEmpty);

      // La correction rouvre la feuille des mensurations, zone verrouillée.
      await tester.tap(
        find
            .descendant(
              of: feuille,
              matching: find.byIcon(AppIcons.editOutline),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Corriger cette mesure'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '81');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Corriger'));
      await tester.pumpAndSettle();

      final taille = await progress.bodyMetrics(kind: BodyMetricKind.waistCm);
      expect(taille.map((m) => (m.id, m.value)), [
        ('taille-1', 85.0),
        ('taille-2', 81.0),
      ]);
    });

    testWidgets('au lecteur d’écran, activer une zone ouvre son histoire', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final progress = FakeProgressRepository(
        bodyMetrics: [
          tour(BodyMetricKind.weightKg, 80, 2),
          tour(BodyMetricKind.waistCm, 85, 30),
          tour(BodyMetricKind.waistCm, 81.5, 1),
        ],
      );
      await ouvrir(tester, progress);
      await reveal(tester, dansLaSection(find.text('Tour de taille')));

      // Le double appui du lecteur d'écran : l'action SÉMANTIQUE, pas un
      // toucher à l'écran.
      final noeud = tester.getSemantics(dansLaSection(find.byType(AppListRow)));
      expect(noeud.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      noeud.owner!.performAction(noeud.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('Tour de taille · 2 mesures'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('indisponibles : un état d’erreur, et le réessai', (
      tester,
    ) async {
      final progress = _MeasurementsDown(
        bodyMetrics: [tour(BodyMetricKind.weightKg, 80, 2)],
      );
      await ouvrir(tester, progress);

      await reveal(tester, find.text('Mensurations indisponibles'));
      progress.down = false;
      await tester.tap(dansLaSection(find.text('Réessayer')));
      await tester.pumpAndSettle();
      expect(find.text('Mensurations indisponibles'), findsNothing);
      expect(find.text('Aucune mensuration'), findsOneWidget);
    });

    testWidgets('un tour sans pesée n’est pas un premier jour', (tester) async {
      final progress = FakeProgressRepository(
        overviewFor: (period) =>
            overviewOf(period, sessionsCount: 0, points: const []),
        bodyMetrics: [tour(BodyMetricKind.hipsCm, 98, 1)],
      );
      await ouvrir(tester, progress);

      expect(find.byType(ProgressFirstSteps), findsNothing);
      await reveal(tester, dansLaSection(find.text('Hanches')));
    });
  });
}

/// Les mensurations tombent (hors ligne), le poids non.
class _MeasurementsDown extends FakeProgressRepository {
  _MeasurementsDown({super.bodyMetrics});

  bool down = true;

  @override
  Future<List<BodyMetricEntry>> bodyMetrics({
    BodyMetricKind kind = BodyMetricKind.weightKg,
    int limit = 90,
  }) {
    if (down && kind.isMeasurement) {
      return Future.error(Exception('hors ligne'));
    }
    return super.bodyMetrics(kind: kind, limit: limit);
  }
}
