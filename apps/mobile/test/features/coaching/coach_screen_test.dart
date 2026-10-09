import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach_thread_state.dart';
import 'package:carlys_mobile/features/coaching/domain/services/coach_suggestions.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_screen.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_composer.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_live_bubble.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_message_bubble.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_suggestions.dart';
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
    name: 'Haut du corps, format court',
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
    CoachMessage(id: 'm2', role: CoachRole.user, content: 'J’ai peu de temps.'),
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
    List<CoachSuggestion> suggestions = const [
      CoachSuggestion('Ajuster ma séance', CoachSuggestionKind.adapt),
    ],
    bool isOffline = false,
    CoachLiveTurn? live,
    ValueChanged<String>? onSend,
    ValueChanged<CoachSessionProposal>? onOpenProposal,
    ValueChanged<CoachCreatedWorkout>? onOpenCreated,
    String? profileLabel,
    VoidCallback? onOpenProfile,
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
          onOpenProgram: (_) {},
          onOpenCreated: onOpenCreated,
          onRetry: () {},
          isOffline: isOffline,
          live: live,
          profileLabel: profileLabel,
          onOpenProfile: onOpenProfile,
        ),
      ),
    );
  }

  testWidgets('une séance ENREGISTRÉE par le coach : sa carte, qui l’ouvre', (
    tester,
  ) async {
    CoachCreatedWorkout? opened;
    await pumpCoach(
      tester,
      messages: const [
        CoachMessage(id: 'q', role: CoachRole.user, content: 'Ok crée-la.'),
        CoachMessage(
          id: 'r',
          role: CoachRole.assistant,
          content: 'C’est enregistré.',
          createdWorkout: (templateId: 'modele-1', name: 'Haut du corps'),
        ),
      ],
      onOpenCreated: (workout) => opened = workout,
    );

    expect(find.text('SÉANCE ENREGISTRÉE'), findsOneWidget);
    expect(find.text('Haut du corps'), findsOneWidget);
    await tester.tap(find.text('Ouvrir dans mes séances'));
    expect(opened?.templateId, 'modele-1');
  });

  testWidgets(
    'une séance PROPOSÉE est gardée : sa carte le dit, sans doublon',
    (tester) async {
      await pumpCoach(
        tester,
        messages: const [
          CoachMessage(id: 'q', role: CoachRole.user, content: 'Séance pecs ?'),
          CoachMessage(
            id: 'r',
            role: CoachRole.assistant,
            content: 'Voilà ta séance.',
            proposal: proposal,
            createdWorkout: (
              templateId: 'p1',
              name: 'Haut du corps, format court',
            ),
          ),
        ],
      );

      expect(find.text('Gardée dans Mes modèles · Coach'), findsOneWidget);
      expect(find.text('Voir la séance'), findsOneWidget);
      expect(find.text('SÉANCE ENREGISTRÉE'), findsNothing);
    },
  );

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

    expect(find.text('Haut du corps, format court'), findsOneWidget);
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

  testWidgets('pendant la rédaction, on ne peut pas doubler la question', (
    tester,
  ) async {
    var sent = 0;
    await pumpCoach(
      tester,
      live: const CoachLiveTurn(question: 'Et demain ?'),
      onSend: (_) => sent++,
    );

    expect(find.byType(CoachLiveBubble), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.send));
    await tester.pump();

    expect(sent, 0);
  });

  testWidgets('sans message, l’écran dit ce qu’il sait faire', (tester) async {
    await pumpCoach(tester, messages: const []);

    expect(find.text('Ton coach est là'), findsOneWidget);
    expect(find.byType(CoachMessageBubble), findsNothing);
  });

  testWidgets('le clavier pousse la barre de saisie au-dessus de lui', (
    tester,
  ) async {
    // Hors coquille, personne d'autre ne relève le corps : c'est le
    // `Scaffold` de cet écran qui doit le faire. Le neutraliser mettrait la
    // barre de saisie DERRIÈRE le clavier, là où l'on écrit sans se voir
    // écrire.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpCoach(tester);
    final full = tester.getRect(find.byType(CoachComposer)).bottom;

    const keyboard = 320.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(CoachComposer)).bottom,
      closeTo(full - keyboard, 1),
    );
  });

  testWidgets('le bouton d’envoi répond aussi au lecteur d’écran', (
    tester,
  ) async {
    // Il est dessiné et touché par un GestureDetector, que la couche
    // d'accessibilité ne voit pas : l'action doit vivre sur le nœud
    // Semantics. Sans elle, le bouton s'annonce sans pouvoir être activé.
    final handle = tester.ensureSemantics();
    var sent = 0;
    await pumpCoach(tester, onSend: (_) => sent++);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Envoyer')),
      isSemantics(
        label: 'Envoyer',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Envoyer'));
    await tester.pump();

    expect(sent, 1);
    handle.dispose();
  });

  testWidgets('pendant l’envoi, il se déclare désactivé', (tester) async {
    // Réessayer dans le vide pendant qu'une question part est le pire des
    // silences : l'état doit être ANNONCÉ, pas seulement grisé.
    final handle = tester.ensureSemantics();
    await pumpCoach(tester, live: const CoachLiveTurn(question: 'Et demain ?'));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Envoyer')),
      isSemantics(label: 'Envoyer', hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('première ouverture + clavier : l’invitation ne déborde pas', (
    tester,
  ) async {
    // Le tout premier geste d'un nouvel utilisateur : ouvrir le coach, qui
    // n'a encore aucun message, et toucher le champ pour poser sa question.
    // L'invitation est alors le seul bloc sans défilement de la colonne : sur
    // un écran court, ou avec le texte système agrandi, elle est rognée.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpCoach(tester, messages: const []);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ton coach est là'), findsOneWidget);
  });

  testWidgets('le champ de saisie est une pilule, pas un rectangle', (
    tester,
  ) async {
    await pumpCoach(tester);

    // Le thème remplit les champs de saisie. Ici la surface est celle du
    // conteneur, en forme de stade : si le champ se remplissait lui aussi,
    // le thème dessinerait un rectangle à angles vifs À L'INTÉRIEUR de la
    // pilule — c'est exactement ce qui était visible à l'écran.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.filled, isFalse);

    // La pilule elle-même : le rayon doit dépasser sa demi-hauteur, sinon
    // ce sont des coins arrondis, pas un stade.
    final pill = find.ancestor(
      of: find.byType(TextField),
      matching: find.byType(Container),
    );
    final box = tester.widget<Container>(pill.first);
    // UNE seule marge, celle du CHAMP : le conteneur n'en ajoute pas. Posée
    // sur lui, elle laissait au doigt un champ de 19 points au milieu d'une
    // pilule qui, autour, ne répondait pas (touch_targets_test.dart).
    expect(box.padding, isNull);
    expect(field.decoration?.contentPadding, isNot(EdgeInsets.zero));
    final radius = (box.decoration! as BoxDecoration).borderRadius!
        .resolve(TextDirection.ltr)
        .topLeft
        .x;
    final height = tester.getSize(find.byType(TextField)).height;
    expect(radius, greaterThan(height / 2));
  });

  testWidgets('la question s’affiche aussitôt, et sa réflexion commence', (
    tester,
  ) async {
    await pumpCoach(
      tester,
      messages: const [],
      // Comme le contrôleur : le chrono part de l'envoi.
      live: CoachLiveTurn(
        question: 'Séance jambes 30 min ?',
        since: DateTime.now(),
      ),
    );

    // Même sur un fil vide : le tour en cours remplace l'invitation.
    expect(find.text('Séance jambes 30 min ?'), findsOneWidget);
    expect(find.text('Réflexion · 0 s'), findsOneWidget);
    expect(find.text('Je réfléchis à ta réponse'), findsOneWidget);
  });

  testWidgets('la réponse s’écrit sous la question, au fil de son arrivée', (
    tester,
  ) async {
    await pumpCoach(
      tester,
      live: const CoachLiveTurn(
        question: 'Et demain ?',
        text: 'Demain, repos actif :',
      ),
    );

    expect(find.text('Demain, repos actif :'), findsOneWidget);
    final question = tester.getRect(find.text('Et demain ?'));
    final reponse = tester.getRect(find.text('Demain, repos actif :'));
    expect(reponse.top, greaterThan(question.bottom));
    // Tant que le tour n'est pas fini, il se dit au travail SOUS le texte.
    final status = tester.getRect(find.text('Écrit…'));
    expect(status.top, greaterThan(reponse.bottom));
  });

  testWidgets('animations réduites : les points ne bougent pas', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpCoach(tester, live: const CoachLiveTurn(question: 'Et demain ?'));

    expect(tester.hasRunningAnimations, isFalse);
  });

  group('accueil d’un fil vide', () {
    testWidgets('les amorces sont des cartes qui envoient leur phrase ; la '
        'bande de puces s’efface', (tester) async {
      final envoyes = <String>[];
      await pumpCoach(
        tester,
        messages: const [],
        onSend: envoyes.add,
        suggestions: const [
          CoachSuggestion(
            'Adapte « Push » à 30 minutes',
            CoachSuggestionKind.adapt,
          ),
        ],
      );

      expect(find.text('POUR COMMENCER'), findsOneWidget);
      expect(find.byType(CoachSuggestions), findsNothing);
      await tester.tap(find.text('Adapte « Push » à 30 minutes'));
      expect(envoyes, ['Adapte « Push » à 30 minutes']);
    });

    testWidgets('« Ton profil » paraît avec un profil, et ouvre son choix', (
      tester,
    ) async {
      var ouvert = false;
      await pumpCoach(
        tester,
        messages: const [],
        profileLabel: 'Stratège',
        onOpenProfile: () => ouvert = true,
      );
      expect(find.text('Stratège'), findsOneWidget);
      await tester.tap(find.text('Stratège'));
      expect(ouvert, isTrue);
    });

    testWidgets('sans profil choisi, aucune pastille vide', (tester) async {
      await pumpCoach(tester, messages: const []);
      expect(find.textContaining('Ton profil'), findsNothing);
    });

    testWidgets('fil commencé : la bande de puces, plus de cartes', (
      tester,
    ) async {
      await pumpCoach(tester);
      expect(find.byType(CoachSuggestions), findsOneWidget);
      expect(find.text('POUR COMMENCER'), findsNothing);
    });
  });
}
