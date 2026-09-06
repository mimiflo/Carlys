import 'package:carlys_mobile/features/community/domain/entities/community_moderation.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La feuille « Signaler » : les motifs du serveur en français, un envoi qui
/// attend un motif, des précisions facultatives nettoyées.
void main() {
  /// Monte un bouton qui ouvre la feuille ; ce qu'elle rend à sa fermeture
  /// est poussé dans [results].
  Future<void> pumpAndOpen(
    WidgetTester tester,
    List<CommunityReportDraft?> results,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  results.add(
                    await showReportSheet(
                      context,
                      title: 'Signaler Sarah',
                      subjectName: 'Sarah',
                    ),
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
  }

  Finder sendButton() =>
      find.widgetWithText(FilledButton, 'Envoyer le signalement');

  testWidgets('les quatre motifs du serveur, libellés en français', (
    tester,
  ) async {
    await pumpAndOpen(tester, []);

    expect(find.text('Harcèlement'), findsOneWidget);
    expect(find.text('Spam ou publicité'), findsOneWidget);
    expect(find.text('Contenu inapproprié'), findsOneWidget);
    expect(find.text('Autre'), findsOneWidget);
    // La feuille dit à qui ça part, et que l'autre n'en saura rien.
    expect(find.textContaining('Sarah n’en saura rien'), findsOneWidget);
  });

  testWidgets('sans motif, l’envoi attend', (tester) async {
    await pumpAndOpen(tester, []);

    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);

    await tester.tap(find.text('Spam ou publicité'));
    await tester.pump();

    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNotNull);
  });

  testWidgets('motif et précisions nettoyées reviennent à l’appelant', (
    tester,
  ) async {
    final results = <CommunityReportDraft?>[];
    await pumpAndOpen(tester, results);
    await tester.tap(find.text('Harcèlement'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '  Trop insistant. ');
    await tester.ensureVisible(sendButton());
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(find.text('Envoyer le signalement'), findsNothing);
    expect(results, hasLength(1));
    expect(results.single?.reason, CommunityReportReason.harassment);
    expect(results.single?.details, 'Trop insistant.');
  });

  testWidgets('des précisions blanches valent « aucune »', (tester) async {
    final results = <CommunityReportDraft?>[];
    await pumpAndOpen(tester, results);
    await tester.tap(find.text('Autre'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.ensureVisible(sendButton());
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(results.single?.details, isNull);
  });

  testWidgets('annuler rend null', (tester) async {
    final results = <CommunityReportDraft?>[];
    await pumpAndOpen(tester, results);
    // La feuille dépasse le viewport de test : elle se fait défiler.
    await tester.ensureVisible(find.text('Annuler'));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer le signalement'), findsNothing);
    expect(results, [null]);
  });
}
