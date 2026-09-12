import 'package:carlys_mobile/features/authentication/presentation/widgets/google_glyph.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/social_auth_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent : l'HONNÊTETÉ des entrées sociales.
///
/// Apple et Google ne sont pas branchés côté API (Étape 2 : e-mail seul).
/// Les boutons existent — la maquette les demande — mais leur toucher doit
/// le DIRE, pas échouer en silence ni simuler une connexion.
void main() {
  Future<void> pump(WidgetTester tester, {bool enabled = true}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SocialAuthButtons(enabled: enabled)),
      ),
    );
  }

  testWidgets('propose Apple et Google, et rien d’autre', (tester) async {
    await pump(tester);

    expect(find.bySemanticsLabel('Continuer avec Apple'), findsOneWidget);
    expect(find.bySemanticsLabel('Continuer avec Google'), findsOneWidget);
    expect(find.byType(GoogleGlyph), findsOneWidget);
    expect(find.text('OU'), findsOneWidget);
    // Pas de Discord, pas d'autre fournisseur : la maquette en montrait
    // trois, la demande en retient deux.
    expect(find.bySemanticsLabel(RegExp('Discord')), findsNothing);
  });

  testWidgets('le toucher annonce que le fournisseur arrive, sans simuler', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Continuer avec Google'));
    await tester.pump();

    expect(
      find.textContaining('La connexion avec Google arrive bientôt'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Continuer avec Apple'));
    await tester.pump();

    expect(
      find.textContaining('La connexion avec Apple arrive bientôt'),
      findsOneWidget,
    );
  });

  testWidgets('neutralisés pendant une soumission', (tester) async {
    await pump(tester, enabled: false);

    await tester.tap(
      find.bySemanticsLabel('Continuer avec Google'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.textContaining('arrive bientôt'), findsNothing);
  });
}
