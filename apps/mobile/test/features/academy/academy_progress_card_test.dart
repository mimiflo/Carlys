import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/domain/academy_progress.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La carte « Où tu en es » : le compte d'abord, le pourcentage avec sa
/// base, le niveau comme jalon — jamais comme note.
void main() {
  Future<void> monter(WidgetTester tester, AcademyProgress progress) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: AcademyProgressCard(progress: progress)),
      ),
    );
  }

  AcademyProgress progression(int abordees, {int total = 38}) =>
      AcademyProgress(
        abordees: abordees,
        total: total,
        parDomaine: {
          AcademyCategory.nutrition: DomainProgress(
            abordees: abordees.clamp(0, 3),
            total: 3,
          ),
        },
      );

  testWidgets('avant la première leçon : le compte, pas de niveau', (
    tester,
  ) async {
    await monter(tester, progression(0));

    expect(find.text('0 leçons sur 38'), findsOneWidget);
    expect(find.text('0 % du pack'), findsOneWidget);
    expect(
      find.textContaining('Niveau'),
      findsNothing,
      reason: 'Un niveau zéro d’office se lirait comme une note d’échec.',
    );
  });

  testWidgets('en cours : niveau, nom, et le prochain pas comme direction', (
    tester,
  ) async {
    await monter(tester, progression(12));

    expect(find.text('12 leçons sur 38'), findsOneWidget);
    expect(find.text('31 % du pack'), findsOneWidget);
    expect(find.text('Niveau 3'), findsOneWidget);
    expect(find.text('Assiduité'), findsOneWidget);
    expect(find.text('encore 8 leçons avant Profondeur'), findsOneWidget);
  });

  testWidgets('au sommet du barème, aucun prochain pas promis', (tester) async {
    await monter(tester, progression(38));

    expect(find.text('100 % du pack'), findsOneWidget);
    expect(find.text('Niveau 5'), findsOneWidget);
    expect(find.text('Érudition'), findsOneWidget);
    expect(find.textContaining('encore'), findsNothing);
  });

  testWidgets('le lecteur d’écran reçoit niveau et prochain pas d’un bloc', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await monter(tester, progression(12));

    expect(
      find.bySemanticsLabel(
        'Niveau 3, Assiduité. encore 8 leçons avant Profondeur',
      ),
      findsOneWidget,
    );

    handle.dispose();
  });
}
