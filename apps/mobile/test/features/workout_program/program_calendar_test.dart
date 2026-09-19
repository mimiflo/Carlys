import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program_calendar.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_calendar_day_row.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : un calendrier qui n'accuse personne à tort, et
/// une date de début qui ne recule pas d'un jour.
///
/// L'état d'une case est DÉDUIT par le serveur ; l'écran ne fait que lui
/// donner une couleur. Le piège est ailleurs : dans le jour civil, qu'un
/// `.toLocal()` réflexe transforme en veille pour tout utilisateur à l'ouest
/// de Greenwich.
void main() {
  ProgramCalendarDay jour({
    required ProgramDayStatus status,
    int dayOfWeek = 1,
    String date = '2026-09-21',
    String? label = 'Push A',
    String? templateId = 'modele-1',
    String? id = 'jour-1',
  }) => ProgramCalendarDay(
    id: id,
    weekNumber: 1,
    dayOfWeek: dayOfWeek,
    date: date,
    status: status,
    templateId: templateId,
    label: label,
    isRest: status == ProgramDayStatus.rest,
  );

  Future<void> monter(WidgetTester tester, ProgramCalendarDay day) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ProgramCalendarDayRow(
            day: day,
            isToday: false,
            onTap: day.isLaunchable ? () {} : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('un jour civil ne se convertit pas', () {
    test('se lit en date LOCALE, jamais en instant UTC', () {
      final date = asLocalDate('2026-09-21');
      // Le 21 reste le 21 : converti en instant puis rendu local, il
      // reculerait d'un jour partout à l'ouest de Greenwich.
      expect(date.year, 2026);
      expect(date.month, 9);
      expect(date.day, 21);
      expect(date.isUtc, isFalse);
    });

    test('un état inconnu du serveur devient « à venir », pas une erreur', () {
      // Un serveur plus récent peut nommer un état que cette version ignore.
      // « À venir » est le seul repli qui n'accuse personne.
      expect(ProgramDayStatus.fromApi('reporte'), ProgramDayStatus.upcoming);
      expect(ProgramDayStatus.fromApi(null), ProgramDayStatus.upcoming);
      expect(ProgramDayStatus.fromApi('missed'), ProgramDayStatus.missed);
    });
  });

  group('la ligne du calendrier', () {
    testWidgets('peint « fait » en vert et « manqué » en rouge', (
      tester,
    ) async {
      await monter(tester, jour(status: ProgramDayStatus.done));
      expect(
        tester.widget<Text>(find.text('Push A')).style?.color,
        AppColors.success,
      );

      await monter(tester, jour(status: ProgramDayStatus.missed));
      expect(
        tester.widget<Text>(find.text('Push A')).style?.color,
        AppColors.danger,
      );
    });

    testWidgets('ne reproche RIEN avant le départ ni sur un jour vide', (
      tester,
    ) async {
      // Commencer un mercredi laisse lundi et mardi derrière soi : ces
      // jours-là n'ont jamais été promis, ils restent gris.
      await monter(tester, jour(status: ProgramDayStatus.before));
      expect(
        tester.widget<Text>(find.text('Push A')).style?.color,
        AppColors.darkTextTertiary,
      );

      await monter(
        tester,
        jour(
          status: ProgramDayStatus.free,
          id: null,
          label: null,
          templateId: null,
        ),
      );
      expect(find.text('Rien de prévu'), findsOneWidget);
    });

    testWidgets('ne propose de lancer que ce qui est lançable', (tester) async {
      // Une case déjà faite ne se relance pas, et un jour sans modèle n'a
      // rien à lancer : une ligne qui répond au doigt sans rien faire se lit
      // comme un défaut.
      expect(jour(status: ProgramDayStatus.upcoming).isLaunchable, isTrue);
      expect(jour(status: ProgramDayStatus.done).isLaunchable, isFalse);
      expect(
        jour(status: ProgramDayStatus.upcoming, templateId: null).isLaunchable,
        isFalse,
      );

      await monter(tester, jour(status: ProgramDayStatus.upcoming));
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
      await monter(tester, jour(status: ProgramDayStatus.done));
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsNothing);
    });
  });

  group('la carte de réglages', () {
    ProgramDetail programme({String? startsOn}) => ProgramDetail(
      id: 'programme-1',
      name: 'Prise de masse',
      weeksCount: 4,
      isActive: true,
      startsOn: startsOn,
      days: const [],
    );

    Future<void> monterCarte(WidgetTester tester, ProgramDetail program) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ProgramSettingsCard(
              program: program,
              onActive: (_) {},
              onStartsOn: (_) {},
              onOpenCalendar: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sans date, elle DIT ce qui manque au lieu de se taire', (
      tester,
    ) async {
      await monterCarte(tester, programme());
      expect(find.text('À choisir'), findsOneWidget);
      expect(find.textContaining('reste une grille'), findsOneWidget);
      // Rien à ouvrir tant qu'il n'y a pas de calendrier.
      expect(find.text('Voir le calendrier'), findsNothing);
    });

    testWidgets('avec une date, elle l’affiche telle qu’elle est stockée', (
      tester,
    ) async {
      await monterCarte(tester, programme(startsOn: '2026-09-21'));
      // Le 21, pas le 20 : le jour civil ne passe par aucun fuseau.
      expect(find.text('21/09/2026'), findsOneWidget);
      expect(find.text('Voir le calendrier'), findsOneWidget);
    });
  });
}
