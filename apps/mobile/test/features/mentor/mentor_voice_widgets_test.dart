import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/mentor/data/flutter_tts_mentor_speaker.dart';
import 'package:carlys_mobile/features/mentor/data/mentor_prefs_store.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_word.dart';
import 'package:carlys_mobile/features/mentor/presentation/providers/mentor_providers.dart';
import 'package:carlys_mobile/features/mentor/presentation/screens/mentor_settings_screen.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_sheet.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_speak_button.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_style_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_mentor_speaker.dart';

/// On l'ENTEND : le bouton « Écouter », la feuille qui dit son mot, le
/// réglage « À voix haute ».
void main() {
  late FakeMentorSpeaker bouche;
  const mot = MentorWord(message: 'Une séance faite vaut mieux qu’une remise.');

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    bouche = FakeMentorSpeaker();
  });

  Widget app(Widget child, {bool lecteurEcran = false}) => ProviderScope(
    overrides: [
      mentorSpeakerProvider.overrideWithValue(bouche),
      currentMentorStyleProvider.overrideWithValue(MentorStyle.bienveillant),
      mentorWordProvider.overrideWithValue(mot),
      mentorTourProgressProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      // Au-dessus du navigateur : la feuille, une route, le voit aussi.
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(accessibleNavigation: lecteurEcran),
        child: page!,
      ),
      home: Scaffold(body: child),
    ),
  );

  Widget ouvreLaFeuille() => Builder(
    builder: (context) => TextButton(
      onPressed: () => showMentorSheet(context),
      child: const Text('Mentor'),
    ),
  );

  testWidgets(
    '« Écouter » le dit ; pendant qu’il parle, le même bouton l’arrête',
    (tester) async {
      await tester.pumpWidget(
        app(const MentorSpeakButton(speechKey: 'k', text: 'Allez.')),
      );

      await tester.tap(find.byTooltip('Écouter'));
      await tester.pump();
      expect(bouche.dits.single.$1, 'Allez.');
      expect(find.byTooltip('Arrêter la voix'), findsOneWidget);

      await tester.tap(find.byTooltip('Arrêter la voix'));
      await tester.pump();
      expect(bouche.arrets, 1);
      expect(find.byTooltip('Écouter'), findsOneWidget);
    },
  );

  testWidgets('sans voix française, il le dit au lieu de rester muet', (
    tester,
  ) async {
    bouche.disponible = false;
    await tester.pumpWidget(
      app(const MentorSpeakButton(speechKey: 'k', text: 'Allez.')),
    );

    await tester.tap(find.byTooltip('Écouter'));
    await tester.pump();
    expect(find.textContaining('pas de voix française'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ouvrir sa feuille : il DIT son mot ; la fermer le fait taire', (
    tester,
  ) async {
    await tester.pumpWidget(app(ouvreLaFeuille()));
    await tester.tap(find.text('Mentor'));
    await tester.pumpAndSettle();

    expect(bouche.dits.single.$1, mot.message);

    Navigator.of(tester.element(find.textContaining(mot.message))).pop();
    await tester.pumpAndSettle();
    expect(bouche.arrets, greaterThanOrEqualTo(1));
  });

  testWidgets('« À voix haute » coupé : la feuille se tait, le bouton reste', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {
      MentorPrefsStore.voixParleeKey: false,
    });
    await tester.pumpWidget(app(ouvreLaFeuille()));
    await tester.tap(find.text('Mentor'));
    await tester.pumpAndSettle();

    expect(bouche.dits, isEmpty);
    expect(find.byTooltip('Écouter'), findsOneWidget);
  });

  testWidgets('lecteur d’écran actif : pas de seconde voix par-dessus', (
    tester,
  ) async {
    await tester.pumpWidget(app(ouvreLaFeuille(), lecteurEcran: true));
    await tester.tap(find.text('Mentor'));
    await tester.pumpAndSettle();

    expect(bouche.dits, isEmpty);
  });

  testWidgets('le lecteur d’écran trouve « Écouter » sur chacune des voix', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    // Un téléphone : la feuille des quatre voix y tient entière.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMentorStyleSheet(context),
            child: const Text('Voix'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Voix'));
    await tester.pumpAndSettle();

    // La carte fond son contenu en un nœud : posé dedans, le bouton y
    // disparaissait. Posé dessus, il est là, une fois par voix.
    final boutons = find.byTooltip('Écouter');
    expect(boutons, findsNWidgets(MentorStyle.values.length));
    for (var i = 0; i < MentorStyle.values.length; i++) {
      // Son PROPRE nœud, annoncé « Écouter » — pas fondu dans la carte.
      final noeud = tester.getSemantics(boutons.at(i)).getSemanticsData();
      expect(noeud.tooltip, 'Écouter');
      expect(noeud.flagsCollection.isButton, isTrue);
    }
    await tester.ensureVisible(find.byTooltip('Écouter').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Écouter').at(2));
    await tester.pump();
    expect(
      bouche.dits.single.$1,
      mentorWordCatalog[MentorStyle.athlete]!.first,
    );
    semantics.dispose();
  });

  testWidgets('le réglage « À voix haute » s’écrit sur l’appareil', (
    tester,
  ) async {
    await tester.pumpWidget(app(const MentorSettingsScreen()));
    await tester.pumpAndSettle();

    // Seconde bascule de la page : « À voix haute » (après « Ses
    // interventions »).
    expect(find.text('À voix haute'), findsOneWidget);
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(MentorPrefsStore.voixParleeKey), isFalse);
  });
}
