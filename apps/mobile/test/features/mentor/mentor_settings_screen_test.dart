import 'dart:ui' show Tristate;

import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/mentor/data/mentor_prefs_store.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_word.dart';
import 'package:carlys_mobile/features/mentor/presentation/providers/mentor_providers.dart';
import 'package:carlys_mobile/features/mentor/presentation/screens/mentor_settings_screen.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_settings_section.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_voice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La page « Mentor Carlys » des réglages : ce qu'elle montre selon que ses
/// interventions sont actives ou non, et ce qu'elle écrit.
void main() {
  const mot = MentorWord(
    message: 'Tu es venu, c’est déjà la partie difficile.',
  );

  Future<void> monter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMentorStyleProvider.overrideWithValue(
            MentorStyle.bienveillant,
          ),
          mentorWordProvider.overrideWithValue(mot),
          mentorTourProgressProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const MentorSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('actives : la fréquence se choisit, son mot est cité', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    await monter(tester);

    expect(find.text('Bienveillant'), findsOneWidget);
    expect(find.text('Fréquence'), findsOneWidget);
    // La page défile : son mot est en bas.
    await tester.scrollUntilVisible(find.text('LE MOT DE LA SEMAINE'), 200);
    expect(find.text('LE MOT DE LA SEMAINE'), findsOneWidget);
    expect(find.textContaining(mot.message), findsOneWidget);
    expect(find.text('Interventions désactivées'), findsNothing);

    await tester.tap(find.text('Quotidienne'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(MentorPrefsStore.frequenceKey), 'jour');
    expect(find.text('LE MOT DU JOUR'), findsOneWidget);
  });

  testWidgets('coupées : ni fréquence ni mot, la carte dit ce que ça change', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {
      MentorPrefsStore.interventionsKey: false,
    });
    await monter(tester);

    await tester.scrollUntilVisible(
      find.text('Interventions désactivées'),
      200,
    );
    expect(find.text('Interventions désactivées'), findsOneWidget);
    expect(find.text('Fréquence'), findsNothing);
    expect(find.textContaining(mot.message), findsNothing);
  });

  testWidgets('la bascule « Ses interventions » s’écrit sur l’appareil', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    await monter(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(MentorPrefsStore.interventionsKey), isFalse);
    await tester.scrollUntilVisible(
      find.text('Interventions désactivées'),
      200,
    );
    expect(find.text('Interventions désactivées'), findsOneWidget);
  });

  testWidgets('le lecteur d’écran entend chaque bascule, nommée et cochée', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {
      MentorPrefsStore.voixParleeKey: false,
    });
    final semantics = tester.ensureSemantics();
    await monter(tester);

    final interventions = tester
        .getSemantics(find.text('Ses interventions'))
        .getSemanticsData();
    expect(interventions.flagsCollection.isToggled, Tristate.isTrue);
    expect(interventions.label, contains('Ses interventions'));
    expect(interventions.hasAction(SemanticsAction.tap), isTrue);

    final voixHaute = tester
        .getSemantics(find.text('À voix haute'))
        .getSemanticsData();
    expect(voixHaute.flagsCollection.isToggled, Tristate.isFalse);
    expect(voixHaute.label, contains('À voix haute'));
    semantics.dispose();
  });

  testWidgets('« Personnaliser le Mentor » des réglages ouvre la page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(child: MentorSettingsSection()),
          ),
        ),
        GoRoute(
          path: AppRoutes.mentor,
          builder: (context, state) => const MentorSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMentorStyleProvider.overrideWithValue(MentorStyle.philosophe),
          mentorWordProvider.overrideWithValue(mot),
          mentorTourProgressProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Philosophe'), findsOneWidget);
    await tester.tap(find.text('Personnaliser le Mentor'));
    await tester.pumpAndSettle();
    expect(find.text('Personnalise ton accompagnement'), findsOneWidget);
  });

  testWidgets('la voix choisie se dit « Voix actuelle », les autres non', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var choisie = <MentorStyle>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ProviderScope(
          child: Scaffold(
            body: ListView(
              children: [
                for (final style in MentorStyle.values)
                  MentorVoiceCard(
                    style: style,
                    selected: style == MentorStyle.exigeant,
                    onTap: () => choisie = [...choisie, style],
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Voix actuelle'), findsOneWidget);
    final exigeant = tester
        .getSemantics(find.text('Exigeant'))
        .getSemanticsData();
    expect(exigeant.label, endsWith('Voix actuelle.'));
    expect(exigeant.flagsCollection.isSelected, Tristate.isTrue);
    final athlete = tester
        .getSemantics(find.text('Athlète'))
        .getSemanticsData();
    expect(athlete.label, isNot(contains('Voix actuelle')));

    await tester.tap(find.text('Athlète'));
    expect(choisie, [MentorStyle.athlete]);
    semantics.dispose();
  });
}
