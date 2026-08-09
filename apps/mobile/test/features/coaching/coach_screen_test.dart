import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_screen.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Écran du coach.
///
/// Ce qui est vérifié ici, c'est ce qui distingue un coach d'un robot de
/// conversation : on voit qui parle, l'échange débouche sur une action, et
/// l'écran dit la vérité quand il ne peut pas répondre.
void main() {
  const proposal = CoachSessionProposal(
    id: 'p1',
    name: 'Haut du corps — format court',
    estimatedMinutes: 25,
    exercises: [
      CoachProposedExercise(
        name: 'Développé couché',
        setCount: 4,
        detail: '6 reps · 60 kg',
      ),
    ],
  );

  const conversation = [
    CoachMessage(
      id: 'm1',
      role: CoachRole.assistant,
      content: 'Comment puis-je t’aider ?',
    ),
    CoachMessage(
      id: 'm2',
      role: CoachRole.user,
      content: 'J’ai peu de temps.',
    ),
    CoachMessage(
      id: 'm3',
      role: CoachRole.assistant,
      content: 'Voici une adaptation.',
      proposal: proposal,
    ),
  ];

  Future<void> pumpCoach(
    WidgetTester tester, {
    List<CoachMessage> messages = conversation,
    List<String> suggestions = const ['Ajuster ma séance'],
    bool isOffline = false,
    bool isSending = false,
    ValueChanged<String>? onSend,
    ValueChanged<CoachSessionProposal>? onOpenProposal,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: CoachScreen(
          messages: messages,
          suggestions: suggestions,
          composerController: controller,
          onSend: onSend ?? (_) {},
          onOpenProposal: onOpenProposal ?? (_) {},
          isOffline: isOffline,
          isSending: isSending,
        ),
      ),
    );
  }

  testWidgets('on voit qui parle sans lire le texte', (tester) async {
    await pumpCoach(tester);

    final coach = tester.getRect(find.text('Comment puis-je t’aider ?'));
    final user = tester.getRect(find.text('J’ai peu de temps.'));
    final screen = tester.getSize(find.byType(CoachScreen));

    // La bulle du coach commence à gauche, celle de l'utilisateur finit à
    // droite : l'alignement seul porte l'information.
    expect(coach.left, lessThan(screen.width / 2));
    expect(user.right, greaterThan(screen.width / 2));
    // Et aucune ne traverse toute la largeur — sinon le bord opposé, qui
    // désigne le locuteur, disparaît.
    expect(coach.width, lessThan(screen.width * 0.85));
    expect(user.width, lessThan(screen.width * 0.85));
  });

  testWidgets('la conversation est ancrée en bas', (tester) async {
    // Deux messages sur un grand écran : s'ils flottaient en haut, la réponse
    // arriverait loin de l'endroit où l'on écrit.
    await pumpCoach(tester, messages: conversation.sublist(0, 2));

    final last = tester.getRect(find.text('J’ai peu de temps.'));
    final screen = tester.getSize(find.byType(CoachScreen));

    expect(last.bottom, greaterThan(screen.height / 2));
  });

  testWidgets('la proposition débouche sur une action', (tester) async {
    CoachSessionProposal? opened;
    await pumpCoach(tester, onOpenProposal: (value) => opened = value);

    expect(find.text('Haut du corps — format court'), findsOneWidget);
    expect(find.text('3 exercices · 25 min'), findsNothing);
    expect(find.text('1 exercice · 25 min'), findsOneWidget);

    await tester.tap(find.text('Voir la séance'));
    await tester.pump();

    expect(opened?.id, 'p1');
  });

  testWidgets('hors ligne, l’écran le dit au lieu d’échouer', (tester) async {
    await pumpCoach(tester, isOffline: true);

    // La saisie disparaît — un envoi hors ligne ne recevrait sa réponse que
    // des heures plus tard, ce qui n'est plus une conversation.
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    // Mais l'historique reste lisible.
    expect(find.text('Voici une adaptation.'), findsOneWidget);
    // Et on ne propose plus d'amorces qu'on ne saurait pas honorer.
    expect(find.text('Ajuster ma séance'), findsNothing);
  });

  testWidgets('pendant la rédaction, on ne peut pas doubler la question',
      (tester) async {
    var sent = 0;
    await pumpCoach(tester, isSending: true, onSend: (_) => sent++);

    expect(find.byType(CoachTypingBubble), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.send));
    await tester.pump();

    expect(sent, 0);
  });

  testWidgets('sans message, l’écran dit ce qu’il sait faire', (tester) async {
    await pumpCoach(tester, messages: const []);

    expect(find.text('Ton coach est là'), findsOneWidget);
    expect(find.byType(CoachMessageBubble), findsNothing);
  });

  testWidgets('le champ de saisie est une pilule, pas un rectangle',
      (tester) async {
    await pumpCoach(tester);

    // Le thème remplit les champs de saisie. Ici la surface est celle du
    // conteneur, en forme de stade : si le champ se remplissait lui aussi,
    // le thème dessinerait un rectangle à angles vifs À L'INTÉRIEUR de la
    // pilule — c'est exactement ce qui était visible à l'écran.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.filled, isFalse);
    expect(field.decoration?.contentPadding, EdgeInsets.zero);

    // La pilule elle-même : le rayon doit dépasser sa demi-hauteur, sinon
    // ce sont des coins arrondis, pas un stade.
    final pill = find.ancestor(
      of: find.byType(TextField),
      matching: find.byType(Container),
    );
    final box = tester.widget<Container>(pill.first);
    final radius = (box.decoration! as BoxDecoration)
        .borderRadius!
        .resolve(TextDirection.ltr)
        .topLeft
        .x;
    final height = tester.getSize(find.byType(TextField)).height;
    expect(radius, greaterThan(height / 2));
  });
}
