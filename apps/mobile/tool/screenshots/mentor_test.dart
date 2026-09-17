// Captures du Plan 3 (Le Mentor Carlys) — OUTIL, exécuté à la demande :
//   flutter test tool/screenshots/mentor_test.dart --update-goldens
//
// Comme les autres fichiers de ce dossier, il est HORS de test/ : la CI ne
// compare jamais ces rendus, et les PNG sont ignorés par git.
//
// Les données d'exemple vivent ici, jamais dans `lib/`. Les mots du Mentor
// sont DÉTERMINISTES par date : chaque capture fige la sienne.
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/for_you_card.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/section_title_bar.dart';
import 'package:carlys_mobile/features/mentor/data/mentor_prefs_store.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_prefs.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_tour.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_word.dart';
import 'package:carlys_mobile/features/mentor/presentation/controllers/mentor_controllers.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_settings_section.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_sheet.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_style_sheet.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_tour_sheet.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/reward_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'capture_test.dart' show loadRealFonts;

/// Une récompense fraîchement gagnée : ce que le Mentor fête.
final _fraiche = EarnedReward(
  reward: const Reward(
    id: 'maitrise-5',
    label: 'Cinq leçons abordées',
    story: 'Cinq questions abordées dans l’Academy.',
    kind: RewardKind.medaille,
  ),
  earnedAt: DateTime.utc(2026, 9, 17),
  isNew: true,
);

void main() {
  setUpAll(loadRealFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  void telephone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  /// Monte un hôte : soit un contenu posé sur l'écran, soit un déclencheur
  /// qui ouvre une feuille — la capture montre alors la feuille elle-même.
  Future<void> monter(
    WidgetTester tester, {
    Widget? corps,
    void Function(BuildContext context)? ouvrir,
    List<Override> overrides = const [],
    MentorStyle? style,
  }) async {
    telephone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMentorStyleProvider.overrideWithValue(style),
          earnedRewardsProvider.overrideWith((ref) async => const []),
          ...overrides,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SafeArea(
              child: Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: ouvrir == null
                      ? corps!
                      : Center(
                          child: TextButton(
                            onPressed: () => ouvrir(context),
                            child: const Text('ouvrir'),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (ouvrir != null) {
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }
  }

  /// La section « Pour toi » telle que l'accueil l'empile : le mot du
  /// Mentor en tête, le cap de l'identité ensuite.
  Widget pourToi(BuildContext context, {required MentorWord mot}) {
    return TitledSection(
      icon: AppIcons.forYou,
      label: 'Pour toi',
      child: ForYouCard(
        entries: [
          ForYouEntry(
            icon: AppIcons.spark,
            iconColor: AppColors.primaryLight,
            iconSize: 20,
            label: 'Le Mentor',
            message: mot.message,
            onOpen: () {},
          ),
          ForYouEntry.focus(context, CarlysProfile.stratege),
        ],
      ),
    );
  }

  testWidgets('le mot du Mentor dans « Pour toi » — voix Exigeant', (
    tester,
  ) async {
    final mot = mentorWord(
      style: MentorStyle.exigeant,
      frequence: MentorFrequency.hebdomadaire,
      now: DateTime(2026, 9, 17),
    );
    await monter(
      tester,
      corps: Builder(builder: (context) => pourToi(context, mot: mot)),
    );
    await capture(tester, 'mentor-01-pour-toi');
  });

  testWidgets('la célébration d’un cap, à la voix Athlète', (tester) async {
    final mot = mentorWord(
      style: MentorStyle.athlete,
      frequence: MentorFrequency.hebdomadaire,
      now: DateTime(2026, 9, 17),
      aFeter: _fraiche,
    );
    await monter(
      tester,
      corps: Builder(builder: (context) => pourToi(context, mot: mot)),
    );
    expect(find.textContaining('Cinq leçons abordées'), findsOneWidget);
    await capture(tester, 'mentor-02-celebration');
  });

  testWidgets('la feuille du Mentor : mot, visite, voix', (tester) async {
    SharedPreferences.setMockInitialValues(const {
      MentorPrefsStore.visiteVuesKey: ['accueil', 'entrainement'],
    });
    await monter(
      tester,
      style: MentorStyle.exigeant,
      ouvrir: showMentorSheet,
    );
    expect(find.text('Le Mentor Carlys'), findsOneWidget);
    await capture(tester, 'mentor-03-feuille');
  });

  testWidgets('le choix de la voix — Exigeant sélectionné', (tester) async {
    await monter(
      tester,
      style: MentorStyle.exigeant,
      ouvrir: showMentorStyleSheet,
    );
    expect(find.text('La voix du Mentor'), findsOneWidget);
    await capture(tester, 'mentor-04-voix');
  });

  testWidgets('la visite guidée — première étape', (tester) async {
    await monter(tester, ouvrir: showMentorTourSheet);
    expect(find.text('Visite guidée · 1 sur 7'), findsOneWidget);
    await capture(tester, 'mentor-05-visite');
  });

  testWidgets('la visite guidée — terminée, et rejouable', (tester) async {
    SharedPreferences.setMockInitialValues({
      MentorPrefsStore.visiteVuesKey: [
        for (final step in mentorTour) step.id,
      ],
    });
    await monter(tester, ouvrir: showMentorTourSheet);
    expect(find.text('Visite terminée'), findsOneWidget);
    await capture(tester, 'mentor-06-visite-terminee');
  });

  testWidgets('les réglages « Mentor Carlys » du profil', (tester) async {
    SharedPreferences.setMockInitialValues(const {
      MentorPrefsStore.visiteVuesKey: ['accueil', 'entrainement'],
    });
    await monter(
      tester,
      style: MentorStyle.philosophe,
      corps: const SingleChildScrollView(child: MentorSettingsSection()),
    );
    expect(find.text('Sa voix'), findsOneWidget);
    await capture(tester, 'mentor-07-reglages');
  });
}
