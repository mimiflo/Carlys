import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// UN ÉCHEC S'ANNONCE (WCAG 4.1.3, messages d'état).
///
/// Hors ligne, un écran passe de « Chargement » à « Hors connexion —
/// Réessayer ». Sous TalkBack ou VoiceOver, rien n'était dit : il fallait
/// explorer l'écran pour découvrir l'échec. L'état d'erreur et l'état vide
/// — ceux qui REMPLACENT un chargement — sont désormais des régions vivantes,
/// que le lecteur d'écran annonce d'office, poliment, dès qu'elles
/// paraissent.
void main() {
  Future<SemanticsNode> annonce(WidgetTester tester, Widget etat) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AppDarkScaffold(body: etat),
      ),
    );
    return tester.getSemantics(find.text('Hors connexion'));
  }

  testWidgets('l’état d’erreur est une région vivante qui dit tout', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final noeud = await annonce(
      tester,
      AppErrorState(
        title: 'Hors connexion',
        message: AppErrorState.retryConnectionMessage,
        onRetry: () {},
      ),
    );

    final data = noeud.getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    expect(noeud.label, contains('Hors connexion'));
    expect(noeud.label, contains(AppErrorState.retryConnectionMessage));
    // Le geste de reprise reste un bouton à part, pas fondu dans l'annonce.
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('l’état vide aussi', (tester) async {
    final semantics = tester.ensureSemantics();
    final noeud = await annonce(
      tester,
      const AppEmptyState(
        title: 'Hors connexion',
        message: 'Rien à montrer pour l’instant.',
      ),
    );

    expect(noeud.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    expect(noeud.label, contains('Rien à montrer pour l’instant.'));
    semantics.dispose();
  });
}
