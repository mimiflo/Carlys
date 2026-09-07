import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/utilities/external_links.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/legal_consent_notice.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_screen.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_data_notice.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_legal_section.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// LES TROIS ENDROITS OÙ CARLYS DOIT PARLER DE SES TEXTES LÉGAUX.
///
/// La politique de confidentialité et les conditions existent et sont
/// servies sur le web depuis la vague 1 ; rien dans l'application n'y menait,
/// et le coach ne disait pas qu'un prestataire externe lit les données citées
/// pour répondre. Trois gestes manquaient : la section des réglages, la
/// phrase sous le bouton d'inscription, et la mention en tête de conversation.
///
/// Ce qui est vérifié : que les adresses viennent bien de la CONFIGURATION
/// (une chaîne en dur pointerait sur localhost en production) et qu'aucun
/// texte n'est recopié dans l'application, où il serait périmé.
void main() {
  const environment = AppEnvironment(
    flavor: AppFlavor.production,
    apiBaseUrl: 'https://api.exemple.test',
    publicWebBaseUrl: 'https://web.exemple.test',
  );

  Widget host(Widget child, List<Uri> opened) => ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(environment),
      externalLinkOpenerProvider.overrideWithValue((url) async {
        opened.add(url);
        return true;
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );

  group('section Légal des réglages', () {
    testWidgets('les deux lignes existent', (tester) async {
      await tester.pumpWidget(host(const ProfileLegalSettings(), []));
      await tester.pumpAndSettle();

      expect(find.text('LÉGAL'), findsOneWidget);
      expect(find.text('Politique de confidentialité'), findsOneWidget);
      expect(find.text('Conditions d’utilisation'), findsOneWidget);
    });

    testWidgets('elles ouvrent les pages web de la CONFIGURATION', (
      tester,
    ) async {
      final opened = <Uri>[];
      await tester.pumpWidget(host(const ProfileLegalSettings(), opened));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Politique de confidentialité'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conditions d’utilisation'));
      await tester.pumpAndSettle();

      expect(opened, [
        Uri.parse('https://web.exemple.test/privacy'),
        Uri.parse('https://web.exemple.test/terms'),
      ]);
    });

    testWidgets('aucun navigateur : on le dit au lieu de ne rien faire', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appEnvironmentProvider.overrideWithValue(environment),
            externalLinkOpenerProvider.overrideWithValue((url) async => false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileLegalSettings()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Politique de confidentialité'));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun navigateur n’a pu ouvrir cette page.'),
        findsOneWidget,
      );
    });
  });

  group('phrase de consentement sous l’inscription', () {
    testWidgets('la phrase est là, et tutoie', (tester) async {
      await tester.pumpWidget(host(const LegalConsentNotice(), []));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('En créant un compte, tu acceptes'),
        findsOneWidget,
      );
      expect(find.textContaining('conditions d’utilisation'), findsOneWidget);
      expect(
        find.textContaining('politique de confidentialité'),
        findsOneWidget,
      );
    });

    testWidgets('les deux morceaux soulignés mènent aux bonnes pages', (
      tester,
    ) async {
      final opened = <Uri>[];
      await tester.pumpWidget(host(const LegalConsentNotice(), opened));
      await tester.pumpAndSettle();

      // Les liens sont des spans : on les atteint par leur position dans le
      // paragraphe, comme le fait un doigt.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      tapSpan(paragraph, 'conditions d’utilisation');
      await tester.pumpAndSettle();
      tapSpan(paragraph, 'politique de confidentialité');
      await tester.pumpAndSettle();

      expect(opened, [
        Uri.parse('https://web.exemple.test/terms'),
        Uri.parse('https://web.exemple.test/privacy'),
      ]);
    });
  });

  group('mention de traitement du coach', () {
    Widget coach(List<CoachMessage> messages) => host(
      CoachScreen(
        messages: messages,
        suggestions: const [],
        composerController: TextEditingController(),
        onSend: (_) {},
        onOpenProposal: (_) {},
      ),
      [],
    );

    testWidgets('elle coiffe le premier message du fil', (tester) async {
      await tester.pumpWidget(
        coach(const [
          CoachMessage(
            id: 'm1',
            role: CoachRole.user,
            content: 'Combien de séries pour les pectoraux ?',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CoachDataNotice), findsOneWidget);
      expect(find.textContaining('prestataire externe'), findsOneWidget);
    });

    testWidgets('elle ne s’affiche qu’UNE fois, quel que soit le nombre de '
        'messages', (tester) async {
      await tester.pumpWidget(
        coach(const [
          CoachMessage(id: 'm1', role: CoachRole.user, content: 'Salut'),
          CoachMessage(id: 'm2', role: CoachRole.assistant, content: 'Salut !'),
          CoachMessage(id: 'm3', role: CoachRole.user, content: 'Et donc ?'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CoachDataNotice), findsOneWidget);
    });

    testWidgets('fil vide : l’invitation reste seule, sans mention', (
      tester,
    ) async {
      await tester.pumpWidget(coach(const []));
      await tester.pumpAndSettle();

      expect(find.byType(CoachDataNotice), findsNothing);
    });
  });
}

/// Appuie sur le morceau de texte [label] d'un paragraphe riche, en appelant
/// le reconnaisseur du span qui le porte.
void tapSpan(RenderParagraph paragraph, String label) {
  TextSpan? link;
  // `Text.rich` emboîte la phrase dans un span de style : la recherche
  // descend donc l'arbre au lieu de ne regarder que le premier niveau.
  paragraph.text.visitChildren((span) {
    if (span is TextSpan &&
        span.text == label &&
        span.recognizer is TapGestureRecognizer) {
      link = span;
      return false;
    }
    return true;
  });

  final recognizer = link?.recognizer;
  if (recognizer is! TapGestureRecognizer || recognizer.onTap == null) {
    fail('Aucun lien « $label » dans le paragraphe.');
  }
  recognizer.onTap!();
}
