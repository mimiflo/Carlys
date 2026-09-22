import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program_calendar.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_calendar_day_sheet.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';

/// LA FEUILLE D'UNE CASE DU CALENDRIER, et le défaut qu'elle ferme.
///
/// Une séance faite HORS calendrier ne portait l'identifiant d'aucune case :
/// elle était bel et bien faite, et sa case restait rouge. Le calendrier
/// accusait d'un manquement quelqu'un qui s'était entraîné, sans recours.
///
/// Ce que ces épreuves gardent, c'est surtout ce que la feuille REFUSE de
/// proposer : « marquer comme fait » ne doit jamais devenir « cocher ».
void main() {
  final aujourdHui = DateTime.now();
  String jourCivil(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  ProgramCalendarDay caseDu({
    required ProgramDayStatus status,
    String? date,
    String? sessionId,
    String? id = 'jour-1',
  }) => ProgramCalendarDay(
    id: id,
    weekNumber: 1,
    dayOfWeek: 1,
    date: date ?? jourCivil(aujourdHui),
    status: status,
    templateId: 'modele-1',
    label: 'Push A',
    isRest: status == ProgramDayStatus.rest,
    sessionId: sessionId,
  );

  WorkoutHistoryEntry seance({
    required String id,
    required DateTime startedAt,
    String name = 'Push A',
    WorkoutStatus status = WorkoutStatus.completed,
    LocalSyncState syncState = LocalSyncState.synced,
  }) => WorkoutHistoryEntry(
    session: WorkoutInfo(
      id: id,
      name: name,
      status: status,
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 48)),
      durationSeconds: 2880,
      syncState: syncState,
    ),
    setsCount: 12,
    totalVolumeKg: 2400,
  );

  /// Ouvre la feuille et rend la BOÎTE où atterrira le geste choisi.
  ///
  /// Une boîte, et pas une valeur : le geste n'est connu qu'APRÈS le tap sur
  /// une option, donc bien après le retour de cette fonction. Rendre la
  /// valeur rendrait toujours `null`.
  Future<_Geste> ouvrir(
    WidgetTester tester, {
    required ProgramCalendarDay day,
    List<WorkoutHistoryEntry> history = const [],
  }) async {
    final geste = _Geste();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(
            FakeWorkoutRepository()..history = history,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  geste.valeur = await showProgramCalendarDaySheet(
                    context,
                    day: day,
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    return geste;
  }

  testWidgets('une case manquée propose la séance FAITE ce jour-là', (
    tester,
  ) async {
    final geste = await ouvrir(
      tester,
      day: caseDu(status: ProgramDayStatus.missed),
      history: [seance(id: 'seance-du-jour', startedAt: aujourdHui)],
    );
    expect(geste.valeur, isNull);

    expect(find.text('Déjà fait ce jour-là ?'.toUpperCase()), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);

    await tester.tap(find.text('Push A'));
    await tester.pumpAndSettle();
    expect((geste.valeur as LinkSessionToDay?)?.sessionId, 'seance-du-jour');
  });

  testWidgets('une séance d’un AUTRE jour n’est jamais proposée', (
    tester,
  ) async {
    // C'est la borne qui empêche « marquer comme fait » de devenir
    // « cocher » : celui qui a déplacé sa séance d'un jour doit déplacer sa
    // CASE, pas mentir sur la date.
    await ouvrir(
      tester,
      day: caseDu(status: ProgramDayStatus.missed),
      history: [
        seance(
          id: 'hier',
          startedAt: aujourdHui.subtract(const Duration(days: 1)),
        ),
      ],
    );

    expect(find.text('Push A'), findsNothing);
    expect(
      find.textContaining('Aucune séance terminée ce jour-là'),
      findsOneWidget,
    );
  });

  testWidgets('une séance EN COURS ne compte pas comme faite', (tester) async {
    await ouvrir(
      tester,
      day: caseDu(status: ProgramDayStatus.missed),
      history: [
        seance(
          id: 'en-cours',
          startedAt: aujourdHui,
          status: WorkoutStatus.inProgress,
        ),
      ],
    );

    expect(
      find.textContaining('Aucune séance terminée ce jour-là'),
      findsOneWidget,
    );
  });

  testWidgets('une séance non synchronisée n’est pas proposée, et c’est DIT', (
    tester,
  ) async {
    // Le serveur ne la connaît pas encore : la proposer mènerait à un refus
    // que personne ne saurait lire. Se taire laisserait croire qu'elle n'a
    // pas eu lieu.
    await ouvrir(
      tester,
      day: caseDu(status: ProgramDayStatus.missed),
      history: [
        seance(
          id: 'pas-encore',
          startedAt: aujourdHui,
          syncState: LocalSyncState.pending,
        ),
      ],
    );

    expect(find.text('Push A'), findsNothing);
    expect(
      find.textContaining('n’est pas encore synchronisée'),
      findsOneWidget,
    );
  });

  testWidgets('une case de REPOS n’offre rien à cocher', (tester) async {
    // `rest` l'emporte sur `done` à l'affichage : une reconnaissance y
    // serait invisible, et le serveur la refuse pour la même raison.
    await ouvrir(
      tester,
      day: caseDu(status: ProgramDayStatus.rest),
      history: [seance(id: 'seance-du-jour', startedAt: aujourdHui)],
    );

    expect(find.text('Déjà fait ce jour-là ?'.toUpperCase()), findsNothing);
    expect(
      find.text('Repos prévu. Le repos fait partie du plan.'),
      findsOneWidget,
    );
  });

  testWidgets('une case FAITE se détache, et ne repropose pas sa séance', (
    tester,
  ) async {
    final geste = await ouvrir(
      tester,
      day: caseDu(status: ProgramDayStatus.done, sessionId: 'deja-liee'),
      history: [seance(id: 'deja-liee', startedAt: aujourdHui)],
    );
    expect(geste.valeur, isNull);

    // Elle honore déjà la case : la reproposer serait un geste sans effet.
    expect(find.text('Push A'), findsNothing);

    await tester.tap(find.text('Ce n’est pas cette séance'));
    await tester.pumpAndSettle();
    expect(geste.valeur, isA<UnlinkSessionFromDay>());
  });

  testWidgets('une case à venir lance, et une case passée ne ment pas', (
    tester,
  ) async {
    final geste = await ouvrir(
      tester,
      day: caseDu(status: ProgramDayStatus.upcoming),
    );
    expect(geste.valeur, isNull);

    await tester.tap(find.text('Lancer la séance'));
    await tester.pumpAndSettle();
    expect(geste.valeur, isA<LaunchDay>());
  });

  group(
    'déplacer la case — le geste que la feuille désignait sans l’avoir',
    () {
      testWidgets('une case à venir propose les six AUTRES jours', (
        tester,
      ) async {
        final geste = await ouvrir(
          tester,
          day: caseDu(status: ProgramDayStatus.upcoming),
        );

        // La case est au LUNDI (`dayOfWeek: 1`) : les sept pastilles sont là,
        // celle du lundi marquée et inerte.
        for (final jour in programDayLabels) {
          expect(find.text(jour), findsOneWidget, reason: jour);
        }

        await tester.tap(find.text('JEU'));
        await tester.pumpAndSettle();
        expect(geste.valeur, isA<MoveDayTo>());
        expect((geste.valeur! as MoveDayTo).dayOfWeek, 4);
      });

      testWidgets('taper le jour ACTUEL ne rend aucun geste', (tester) async {
        // La pastille du jour courant est inerte : elle marque, elle n'agit
        // pas. Un geste vers soi-même ferait un aller-retour serveur pour
        // rien — et la règle du domaine le rendrait de toute façon inchangé.
        final geste = await ouvrir(
          tester,
          day: caseDu(status: ProgramDayStatus.upcoming),
        );

        await tester.tap(find.text('LUN'));
        await tester.pumpAndSettle();
        expect(geste.valeur, isNull);
      });

      testWidgets('une case DÉJÀ honorée ne se déplace pas', (tester) async {
        // Son identifiant porte le lien avec la séance qui l'a honorée : la
        // déplacer emporterait ce fait vers une autre date, et ferait dire au
        // calendrier qu'on s'est entraîné un jour où on ne s'est pas entraîné.
        await ouvrir(
          tester,
          day: caseDu(status: ProgramDayStatus.done, sessionId: 'seance-1'),
        );

        expect(find.text('Déplacer vers'), findsNothing);
        expect(find.text('JEU'), findsNothing);
      });

      testWidgets('une case d’AVANT le départ non plus', (tester) async {
        await ouvrir(tester, day: caseDu(status: ProgramDayStatus.before));

        expect(find.text('Déplacer vers'), findsNothing);
      });

      testWidgets('un jour VIDE n’a pas de case à déplacer', (tester) async {
        // `id` nul : le calendrier montre les sept jours, y compris ceux
        // qu'aucune case n'occupe. Il n'y a rien à bouger.
        await ouvrir(
          tester,
          day: caseDu(status: ProgramDayStatus.free, id: null),
        );

        expect(find.text('Déplacer vers'), findsNothing);
      });
    },
  );
}

/// La boîte où le geste choisi atterrit, une fois la feuille refermée.
class _Geste {
  CalendarDayAction? valeur;
}
