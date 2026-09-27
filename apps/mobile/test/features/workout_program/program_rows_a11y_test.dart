import 'dart:ui' show Tristate;

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program_calendar.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_calendar_day_row.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_settings_card.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_week_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// LA FICHE D'UN PROGRAMME ET SON CALENDRIER, au doigt et au lecteur
/// d'écran.
///
/// Ouvrir ou déplacer un jour se faisait sur une ligne de 27 points de haut
/// (38 dans le calendrier daté) : viser la bonne journée entre deux lignes
/// serrées était difficile, et le lecteur d'écran ne les annonçait pas comme
/// des boutons. La bascule « Programme suivi », elle, s'annonçait sans nom.
void main() {
  // Les vraies polices : la police de test, plus haute, donnait à la ligne
  // du calendrier daté 50 points là où un téléphone en mesure 38.
  setUpAll(loadAppFonts);

  Widget monte(Widget enfant) => MaterialApp(
    theme: AppTheme.dark(),
    home: AppDarkScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: enfant,
      ),
    ),
  );

  const programme = ProgramDetail(
    id: 'programme-1',
    name: 'Force en 2 semaines',
    weeksCount: 2,
    isActive: true,
    startsOn: '2026-09-21',
    days: [
      ProgramDayEntry(
        id: 'jour-1',
        weekNumber: 1,
        dayOfWeek: 1,
        label: 'Push force',
        templateId: 'modele-1',
        isRest: false,
      ),
      ProgramDayEntry(
        id: 'jour-2',
        weekNumber: 1,
        dayOfWeek: 2,
        label: 'Repos',
        isRest: true,
      ),
    ],
  );

  testWidgets('chaque jour de la semaine est un bouton de 48 points', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final ouverts = <int>[];
    await tester.pumpWidget(
      monte(
        ProgramWeekView(
          weekNumber: 1,
          program: programme,
          onEditDay: ouverts.add,
        ),
      ),
    );

    Finder ligne(String jour) => find
        .ancestor(of: find.text(jour), matching: find.byType(InkWell))
        .first;
    for (final jour in programDayLabels) {
      expect(
        tester.getSize(ligne(jour)).height,
        greaterThanOrEqualTo(AppSpacing.touchTarget),
        reason: jour,
      );
    }
    expect(
      tester.getSemantics(find.text('Push force')),
      isSemantics(isButton: true, hasTapAction: true),
    );

    // Le HAUT de la cible, au-dessus du texte : il répond aussi.
    final premiere = tester.getRect(ligne(programDayLabels.first));
    await tester.tapAt(premiere.topCenter + const Offset(0, 2));
    expect(ouverts, [1]);
    semantics.dispose();
  });

  testWidgets('un jour du calendrier daté est un bouton de 48 points', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var touches = 0;
    await tester.pumpWidget(
      monte(
        ProgramCalendarDayRow(
          day: const ProgramCalendarDay(
            id: 'jour-1',
            weekNumber: 1,
            dayOfWeek: 1,
            date: '2026-09-21',
            status: ProgramDayStatus.upcoming,
            isRest: false,
            templateId: 'modele-1',
            label: 'Push force',
          ),
          isToday: true,
          onTap: () => touches++,
        ),
      ),
    );

    final ligne = find.byType(ProgramCalendarDayRow);
    expect(
      tester.getSize(ligne).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
    expect(
      tester.getSemantics(find.text('Push force')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    await tester.tapAt(tester.getRect(ligne).topCenter + const Offset(0, 2));
    expect(touches, 1);
    semantics.dispose();
  });

  testWidgets('la bascule « Programme suivi » porte son nom', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      monte(
        ProgramSettingsCard(
          program: programme,
          onActive: (_) {},
          onStartsOn: (_) {},
          onOpenCalendar: () {},
        ),
      ),
    );

    final noeud = tester.getSemantics(find.byType(Switch));
    expect(noeud.label, 'Programme suivi');
    expect(noeud.getSemanticsData().flagsCollection.isToggled, Tristate.isTrue);
    semantics.dispose();
  });
}
