import 'dart:async';

import 'package:carlys_mobile/core/brand/carlys_manifesto.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/progression_engine.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/progression_controllers.dart';
import 'package:carlys_mobile/features/progression/presentation/screens/manifesto_screen.dart';
import 'package:carlys_mobile/features/progression/presentation/screens/progression_screen.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/axes_card.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/progression_gauge.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/controllers/workout_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les deux écrans de marque : ce qu'ils montrent, et surtout ce qu'ils
/// REFUSENT de montrer.
void main() {
  /// Écran HAUT : les deux pages défilent, et chercher un texte sous le pli
  /// ne le trouverait pas. On agrandit la fenêtre plutôt que de faire
  /// défiler à chaque assertion — ce qui est vérifié ici, c'est le contenu,
  /// pas le défilement.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
          ..physicalSize = const Size(1200, 4200)
          ..devicePixelRatio = 3;
    addTearDown(view.reset);
  });

  Widget host(
    Widget child, {
    ProgressionProfile? profile,
    bool unreadable = false,
  }) => ProviderScope(
    overrides: [
      progressionProfileProvider.overrideWithValue(profile),
      progressionUnreadableProvider.overrideWithValue(unreadable),
      // L'avatar est la SEULE chose que l'écran tire de la session : on
      // le fournit ici pour que le reste se vérifie sans amorçage.
      progressionInitialProvider.overrideWithValue('M'),
    ],
    child: MaterialApp(home: child),
  );

  group('profil de progression', () {
    testWidgets('un axe en attente n’affiche NI jauge NI zéro', (tester) async {
      // Un « 0 » et une jauge vide se lisent comme un échec. La vérité est
      // qu'il n'y a pas encore de données, et c'est ce qui doit s'écrire.
      final blank = computeProgression(
        ProgressionFacts(today: DateTime(2026, 8, 15)),
      );

      await tester.pumpWidget(host(const ProgressionScreen(), profile: blank));
      await tester.pumpAndSettle();

      expect(find.text('EN ATTENTE'), findsNWidgets(CarlysValue.values.length));
      // AUCUNE jauge remplie, titre compris : rien n'est encore acquis. Les
      // pistes existent, en tirets — jamais une piste vide.
      final gauges = tester.widgetList<ProgressionGauge>(
        find.byType(ProgressionGauge),
      );
      expect(gauges, hasLength(CarlysValue.values.length + 1));
      expect(gauges.every((gauge) => gauge.fill == null), isTrue);
      expect(
        find.descendant(of: find.byType(AxisRow), matching: find.text('0')),
        findsNothing,
      );
    });

    testWidgets('un profil nourri montre son titre et ses points', (
      tester,
    ) async {
      final today = DateTime(2026, 8, 15);
      final profile = computeProgression(
        ProgressionFacts(
          today: today,
          completedSessionDays: [
            for (final age in [0, 3, 7, 10, 14, 17, 21, 24])
              today.subtract(Duration(days: age)),
          ],
          startedSessions: 8,
          completedSessions: 8,
          recentVolumeKg: 12000,
          previousVolumeKg: 10000,
          lessonsAnswered: 11,
          lessonsTotal: 22,
        ),
      );

      await tester.pumpWidget(
        host(const ProgressionScreen(), profile: profile),
      );
      await tester.pumpAndSettle();

      expect(find.text(profile.title.label), findsOneWidget);
      expect(find.text('${profile.points}'), findsOneWidget);
      // Chaque axe explique son pourquoi : aucune carte muette.
      for (final axis in profile.axes) {
        expect(
          find.text(axis.reason),
          findsOneWidget,
          reason: axis.value.label,
        );
      }
    });

    testWidgets('sans historique lu, on patiente au lieu d’inventer', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ProgressionScreen()));
      await tester.pump();

      expect(find.text('Apprenti'), findsNothing);
      expect(find.byType(ProgressionScreen), findsOneWidget);
    });

    testWidgets('un historique illisible se DIT, au lieu de tourner sans fin', (
      tester,
    ) async {
      // Le profil se dérive de l'historique local : s'il ne se lit pas, le
      // patienter éternellement ressemble à un calcul sans fin. On le dit,
      // et on propose de reprendre.
      await tester.pumpWidget(
        host(const ProgressionScreen(), unreadable: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ton historique n’a pas pu être lu'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      // Et surtout aucun titre inventé pour meubler.
      expect(find.text('Apprenti'), findsNothing);
    });
  });

  group('lecture de l’historique', () {
    test('une base illisible se signale', () async {
      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            (ref) => Stream<List<WorkoutHistoryEntry>>.error(
              StateError('base illisible'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(progressionUnreadableProvider, (_, __) {});
      await pumpEventQueue();

      expect(sub.read(), isTrue);
    });

    test('une émission perdue APRÈS coup ne cache pas le profil', () async {
      // Un flux qui échoue une fois garde sa dernière valeur : afficher une
      // erreur par-dessus des données réelles serait mentir dans l'autre sens.
      final source = StreamController<List<WorkoutHistoryEntry>>();
      addTearDown(source.close);
      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith((ref) => source.stream),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(progressionUnreadableProvider, (_, __) {});
      source.add(const []);
      await pumpEventQueue();
      source.addError(StateError('lecture perdue'));
      await pumpEventQueue();

      expect(sub.read(), isFalse);
    });
  });

  group('manifeste', () {
    testWidgets('les quatre phrases et les cinq valeurs y sont', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ManifestoScreen()));
      await tester.pumpAndSettle();

      for (final line in carlysManifesto) {
        expect(find.text(line), findsOneWidget);
      }
      for (final value in CarlysValue.values) {
        expect(find.text(value.label.toUpperCase()), findsOneWidget);
        expect(find.text(value.promise), findsOneWidget);
      }
    });

    testWidgets('il ne montre AUCUN point : un manifeste n’est pas un score', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ManifestoScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('points'), findsNothing);
    });
  });
}
