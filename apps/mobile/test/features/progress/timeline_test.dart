import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/screens/timeline_screen.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/timeline_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_progress_repository.dart';

/// LA FRISE : ce qui s'est passé, dans l'ordre.
///
/// Ce que ce fichier protège : les en-têtes de mois se posent ICI (découpés
/// côté serveur, une page vaudrait deux lignes ou deux cents) ; la page déjà
/// lue RESTE quand la suivante échoue ; et une ligne se lit entièrement
/// depuis son `payload`, sans seconde requête.
void main() {
  ProgressEvent event(
    ProgressEventKind kind,
    DateTime at, {
    Map<String, dynamic> payload = const {},
    String? id,
  }) => ProgressEvent(
    id: id ?? '${kind.apiValue}-${at.toIso8601String()}',
    kind: kind,
    occurredAt: at,
    payload: payload,
  );

  Widget host(FakeProgressRepository repository) => ProviderScope(
    overrides: [progressRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: AppTheme.dark(), home: const TimelineScreen()),
  );

  FakeProgressRepository avec(List<ProgressEvent> events) {
    final repository = FakeProgressRepository();
    repository.timelineEvents.addAll(events);
    return repository;
  }

  testWidgets('une frise vide invite, elle ne reste pas muette', (
    tester,
  ) async {
    await tester.pumpWidget(host(avec(const [])));
    await tester.pumpAndSettle();

    expect(find.text('Ton histoire commence'), findsOneWidget);
    expect(find.byType(TimelineRow), findsNothing);
  });

  testWidgets('chaque ligne se lit depuis son payload, sans autre requête', (
    tester,
  ) async {
    final repository = avec([
      event(
        ProgressEventKind.session,
        DateTime.utc(2026, 8, 20, 18),
        payload: {'name': 'Push A', 'setsCount': 14, 'volumeKg': 4200},
      ),
      event(
        ProgressEventKind.record,
        DateTime.utc(2026, 8, 18, 18),
        payload: {
          'exerciseName': 'Développé couché',
          'recordType': 'MAX_WEIGHT',
          'value': 85,
        },
      ),
      event(
        ProgressEventKind.measure,
        DateTime.utc(2026, 8, 15, 8),
        payload: {'metricType': 'WEIGHT_KG', 'value': 78.4},
      ),
      event(
        ProgressEventKind.lesson,
        DateTime.utc(2026, 8, 12, 12),
        payload: {'lessons': 4},
      ),
    ]);

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Développé couché'), findsOneWidget);
    expect(find.text('85 kg'), findsOneWidget);
    expect(find.text('Pesée'), findsOneWidget);
    expect(find.text('78,4 kg'), findsOneWidget);
    expect(find.text('4 leçons abordées'), findsOneWidget);
  });

  testWidgets('les en-têtes de MOIS se posent côté client', (tester) async {
    final repository = avec([
      event(ProgressEventKind.session, DateTime.utc(2026, 8, 20, 18)),
      event(ProgressEventKind.session, DateTime.utc(2026, 8, 5, 18)),
      event(ProgressEventKind.session, DateTime.utc(2026, 7, 28, 18)),
    ]);

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    // Deux mois, deux en-têtes — et UN seul pour les deux séances d'août.
    // `AppSectionLabel` capitalise ce qu'on lui donne.
    expect(find.text('AOÛT 2026'), findsOneWidget);
    expect(find.text('JUILLET 2026'), findsOneWidget);
  });

  testWidgets('le filtre recharge depuis le début', (tester) async {
    final repository = avec([
      event(ProgressEventKind.session, DateTime.utc(2026, 8, 20, 18)),
      event(
        ProgressEventKind.record,
        DateTime.utc(2026, 8, 18, 18),
        payload: {
          'exerciseName': 'Squat',
          'recordType': 'MAX_WEIGHT',
          'value': 120,
        },
      ),
    ]);

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();
    expect(find.byType(TimelineRow), findsNWidgets(2));

    await tester.tap(find.text('Franchissements'));
    await tester.pumpAndSettle();

    // Mêler deux filtres dans une même liste n'aurait aucun sens : on
    // repart de la première page.
    expect(find.byType(TimelineRow), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('retaper le filtre ACTIF ne vide pas l’écran', (tester) async {
    final repository = avec([
      event(ProgressEventKind.session, DateTime.utc(2026, 8, 20, 18)),
    ]);

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tout'));
    await tester.pumpAndSettle();

    expect(find.byType(TimelineRow), findsOneWidget);
  });

  testWidgets('serveur muet : une erreur avec son réessai', (tester) async {
    final repository = FakeProgressRepository()..timelineFails = true;

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Histoire indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('la page déjà lue RESTE quand la suivante échoue', (
    tester,
  ) async {
    // Trente-et-un événements : une page pleine, plus un — de quoi demander
    // la suite.
    final repository = avec([
      for (var index = 0; index < 31; index++)
        event(
          ProgressEventKind.session,
          DateTime.utc(2026, 8, 20, 18).subtract(Duration(days: index)),
          id: 'seance-$index',
        ),
    ]);

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    // La suite ne viendra pas.
    repository.timelineFails = true;
    // La barre de filtres est elle aussi une `ListView` : on vise la
    // VERTICALE, celle de la frise.
    await tester.drag(
      find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.vertical,
      ),
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();

    // Perdre trente lignes parce que la trente-et-unième n'est pas venue
    // serait une punition pour un réseau qui flanche.
    expect(find.byType(TimelineRow), findsWidgets);
    expect(
      find.textContaining('La suite n’a pas pu être chargée'),
      findsOneWidget,
    );
  });

  testWidgets('une récompense se NOMME, depuis le catalogue embarqué', (
    tester,
  ) async {
    // Le serveur ne stocke que la clé : le libellé est du contenu éditorial,
    // qui change avec l'application. « Récompense obtenue » tout court ne
    // nommait rien et ne menait nulle part.
    final repository = avec([
      event(
        ProgressEventKind.reward,
        DateTime.utc(2026, 8, 20, 18),
        payload: {'key': 'constance-4'},
      ),
      // Une clé d'une version plus récente : la ligne retombe sur son titre
      // générique plutôt que de disparaître.
      event(
        ProgressEventKind.reward,
        DateTime.utc(2026, 8, 19, 18),
        payload: {'key': 'venue-du-futur'},
      ),
    ]);

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Récompense obtenue'), findsOneWidget);
    expect(find.byType(TimelineRow), findsNWidgets(2));
  });

  group('la ligne d’un franchissement se distingue', () {
    test('les trois types de franchissement se reconnaissent', () {
      expect(ProgressEventKind.record.isMilestone, isTrue);
      expect(ProgressEventKind.reward.isMilestone, isTrue);
      expect(ProgressEventKind.title.isMilestone, isTrue);
      expect(ProgressEventKind.session.isMilestone, isFalse);
      expect(ProgressEventKind.measure.isMilestone, isFalse);
      expect(ProgressEventKind.lesson.isMilestone, isFalse);
    });

    test('un type inconnu est IGNORÉ, pas rendu vide', () {
      // Un serveur plus récent peut inventer un type : une frise ne montre
      // pas des trous.
      expect(ProgressEventKind.fromApi('PHOTO'), isNull);
      expect(ProgressEventKind.fromApi('RECORD'), ProgressEventKind.record);
    });
  });
}
