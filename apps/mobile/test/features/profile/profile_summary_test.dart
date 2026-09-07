import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/nutrition_controllers.dart';
import 'package:carlys_mobile/features/profile/presentation/controllers/profile_controllers.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_plan_card.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_stat_tiles.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_summary.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/controllers/progress_controllers.dart';
import 'package:carlys_mobile/features/subscription/domain/entities/subscription.dart';
import 'package:carlys_mobile/features/subscription/presentation/controllers/subscription_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_progress_repository.dart';

/// LE PROFIL NE MENT PAS PAR OMISSION.
///
/// Quatre sources serveur nourrissent la bannière d'abonnement et les tuiles
/// de chiffres, et l'écran les lisait toutes au `valueOrNull`. Hors réseau,
/// la bannière et les tuiles disparaissaient donc SANS UN MOT : l'écran
/// affirmait, par leur absence, que l'utilisateur n'avait ni abonnement, ni
/// poids, ni taille, ni séance.
///
/// Ce fichier défend la distinction entre « pas pu » et « rien ».
void main() {
  const plan = PlanStatus(planName: 'Premium', isPremium: true);

  MetabolismReport reportWith(double heightCm) => MetabolismReport(
    profile: MetabolicProfile(heightCm: heightCm),
    missing: const [],
  );

  // Ce que les quatre sources servent quand elles répondent. Les valeurs sont
  // écrites UNE fois : le test du réessai les relit, et les chiffres attendus
  // à l'écran restent les mêmes que partout ailleurs dans ce fichier.
  final rapport = reportWith(180);
  final apercuAnnee = overviewOf(ProgressPeriod.year, sessionsCount: 42);
  final mesures = [
    BodyMetricEntry(
      id: 'm-1',
      kind: BodyMetricKind.weightKg,
      value: 78.4,
      measuredAt: DateTime.utc(2026, 9, 1),
    ),
  ];

  /// Le bloc SEUL, avec ses quatre sources pilotées une à une. Aucun autre
  /// provider n'entre dans sa décision : rien d'autre n'est donc doublé, et
  /// aucune base Drift ne s'ouvre.
  Future<void> pumpSummary(
    WidgetTester tester, {
    required List<Override> sources,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: sources,
        child: MaterialApp(
          home: Scaffold(body: ProfileSummary(onOpenPlan: () {})),
        ),
      ),
    );
    await tester.pump();
  }

  /// Les quatre sources servies, sauf celles que le test remplace.
  List<Override> serving({
    Override? planSource,
    Override? reportSource,
    Override? sessionsSource,
    Override? weightsSource,
  }) => [
    planSource ?? planStatusProvider.overrideWith((ref) async => plan),
    reportSource ??
        metabolismReportProvider.overrideWith((ref) async => rapport),
    sessionsSource ??
        profileSessionsOverviewProvider.overrideWith(
          (ref) async => apercuAnnee,
        ),
    weightsSource ??
        bodyWeightMetricsProvider.overrideWith((ref) async => mesures),
  ];

  testWidgets('hors ligne : l’écran le DIT, il ne se contente pas de vider', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      sources: serving(
        planSource: planStatusProvider.overrideWith(
          (ref) async => throw const NetworkException('socket'),
        ),
      ),
    );

    expect(find.text('Hors connexion'), findsOneWidget);
    expect(
      find.text(
        'Ton abonnement et tes chiffres vivent sur le serveur. '
        'Ils reviennent avec le réseau.',
      ),
      findsOneWidget,
    );
    // Et rien n'affirme le contraire à côté : ni bannière, ni tuile.
    expect(find.byType(ProfilePlanCard), findsNothing);
    expect(find.byType(ProfileStatTiles), findsNothing);
  });

  testWidgets('serveur en panne : l’échec générique, avec un réessai', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      sources: serving(
        sessionsSource: profileSessionsOverviewProvider.overrideWith(
          (ref) async => throw const ServerException('500'),
        ),
      ),
    );

    expect(find.text('Profil indisponible'), findsOneWidget);
    expect(
      find.text('Ton abonnement et tes chiffres n’ont pas pu être chargés.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Hors connexion'), findsNothing);
  });

  testWidgets('serveur qui tarde : rien n’est affirmé', (tester) async {
    await pumpSummary(
      tester,
      sources: serving(
        planSource: planStatusProvider.overrideWith(
          (ref) => Completer<PlanStatus>().future,
        ),
        reportSource: metabolismReportProvider.overrideWith(
          (ref) => Completer<MetabolismReport>().future,
        ),
        sessionsSource: profileSessionsOverviewProvider.overrideWith(
          (ref) => Completer<ProgressOverviewEntity>().future,
        ),
        weightsSource: bodyWeightMetricsProvider.overrideWith(
          (ref) => Completer<List<BodyMetricEntry>>().future,
        ),
      ),
    );

    // Ni échec annoncé, ni chiffre inventé : l'attente ne prétend rien.
    expect(find.text('Profil indisponible'), findsNothing);
    expect(find.text('Hors connexion'), findsNothing);
    expect(find.byType(ProfilePlanCard), findsNothing);
  });

  testWidgets('serveur qui répond : la bannière et les trois chiffres', (
    tester,
  ) async {
    await pumpSummary(tester, sources: serving());
    // Les quatre futures se résolvent au micro-tâche suivante.
    await tester.pump();

    expect(find.byType(ProfilePlanCard), findsOneWidget);
    expect(find.text('Premium'), findsWidgets);
    // Les tuiles composent la valeur et son unité dans un SEUL `Text.rich` :
    // le finder les lit collées, et il lui faut `findRichText`.
    expect(find.text('78,4kg', findRichText: true), findsOneWidget);
    expect(find.text('180cm', findRichText: true), findsOneWidget);
    expect(find.text('42', findRichText: true), findsOneWidget);
    expect(find.text('Hors connexion'), findsNothing);
    expect(find.text('Profil indisponible'), findsNothing);
  });

  testWidgets('« Réessayer » relit VRAIMENT les quatre sources', (
    tester,
  ) async {
    // Un bouton de réessai qui ne relit rien vaut moins qu'aucun bouton :
    // l'utilisateur croit avoir agi. On compte donc les lectures — LES
    // QUATRE, une par source. N'en compter qu'une ne prouvait rien des trois
    // autres : mesuré, trois invalidations retirées du code de production
    // laissaient ce test vert, alors que trois des quatre blocs seraient
    // restés en échec sous les yeux de l'utilisateur.
    final lectures = <String, int>{
      'abonnement': 0,
      'métabolisme': 0,
      'séances': 0,
      'poids': 0,
    };

    /// Une source qui ÉCHOUE au premier appel et sert au second : sans le
    /// second appel, son compteur reste à 1 et le bloc reste en échec.
    Future<T> premierEchec<T>(String source, T valeur) async {
      final rang = (lectures[source] = lectures[source]! + 1);
      if (rang == 1) {
        throw const NetworkException('socket');
      }
      return valeur;
    }

    await pumpSummary(
      tester,
      sources: [
        planStatusProvider.overrideWith(
          (ref) => premierEchec('abonnement', plan),
        ),
        metabolismReportProvider.overrideWith(
          (ref) => premierEchec('métabolisme', rapport),
        ),
        profileSessionsOverviewProvider.overrideWith(
          (ref) => premierEchec('séances', apercuAnnee),
        ),
        bodyWeightMetricsProvider.overrideWith(
          (ref) => premierEchec('poids', mesures),
        ),
      ],
    );

    expect(find.text('Hors connexion'), findsOneWidget);
    expect(lectures.values, everyElement(1));

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump();

    // Le cœur du test : CHAQUE source a été relue, aucune n'est restée sur
    // son échec.
    expect(
      lectures,
      {'abonnement': 2, 'métabolisme': 2, 'séances': 2, 'poids': 2},
      reason:
          'Une source lue une seule fois n’a pas été invalidée : son bloc '
          'reste en échec pendant que les autres reviennent.',
    );
    expect(find.text('Hors connexion'), findsNothing);
    expect(find.byType(ProfilePlanCard), findsOneWidget);
    // Et les trois chiffres sont bien revenus, pas seulement la bannière.
    expect(find.text('78,4kg', findRichText: true), findsOneWidget);
    expect(find.text('180cm', findRichText: true), findsOneWidget);
    expect(find.text('42', findRichText: true), findsOneWidget);
  });
}
