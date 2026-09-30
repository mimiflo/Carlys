import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_composer.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_live_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le coach sollicité (ADR 0013) : l'attente se dit, et une réponse en
/// cours s'arrête d'un geste.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('la bulle en cours', () {
    testWidgets('en file : combien passent avant', (tester) async {
      await pump(tester, const CoachLiveBubble(text: '', ahead: 2));
      expect(find.text('En attente · 2 avant toi'), findsOneWidget);
    });

    testWidgets('en tête de file : « tu es le prochain »', (tester) async {
      await pump(tester, const CoachLiveBubble(text: '', ahead: 0));
      expect(find.text('En attente · tu es le prochain'), findsOneWidget);
    });

    testWidgets('son tour venu : il réfléchit', (tester) async {
      await pump(tester, const CoachLiveBubble(text: ''));
      expect(find.text('Réfléchit…'), findsOneWidget);
    });
  });

  group('le composeur pendant une réponse', () {
    testWidgets('« Arrêter » remplace l’envoi, et arrête', (tester) async {
      final controller = TextEditingController(text: 'Demain ?');
      addTearDown(controller.dispose);
      var stopped = 0;
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: CoachComposer(
            controller: controller,
            onSend: (_) {},
            onRetry: () {},
            onStop: () => stopped++,
            isSending: true,
          ),
        ),
      );

      expect(find.byIcon(AppIcons.send), findsNothing);
      expect(find.bySemanticsLabel('Arrêter'), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.stop));
      expect(stopped, 1);
    });

    testWidgets('sans réponse en cours : le bouton d’envoi', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: CoachComposer(
            controller: controller,
            onSend: (_) {},
            onRetry: () {},
            onStop: () {},
          ),
        ),
      );

      expect(find.byIcon(AppIcons.send), findsOneWidget);
      expect(find.byIcon(AppIcons.stop), findsNothing);
    });
  });
}
