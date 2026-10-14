import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/mentor/data/flutter_tts_mentor_speaker.dart';
import 'package:carlys_mobile/features/mentor/data/mentor_prefs_store.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_speaker.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_tour.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_voice.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_tour_card.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_tour_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Muet implements MentorSpeaker {
  @override
  Future<void> speak(String text, MentorVoice voice) async {}

  @override
  Future<void> stop() async {}
}

/// La feuille de la visite : la dernière étape se TERMINE, la fin se revoit,
/// et les deux portes qui naviguent ferment la feuille avant d'y aller.
void main() {
  late GoRouter router;

  Future<void> ouvrir(WidgetTester tester, int vues) async {
    SharedPreferences.setMockInitialValues({
      MentorPrefsStore.visiteVuesKey: [
        for (final step in mentorTour.take(vues)) step.id,
      ],
    });
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // Départ ailleurs qu'à l'accueil : la feuille s'ouvre aussi depuis les
    // réglages du Mentor.
    Widget page(String nom) => Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: [
            Text(nom),
            TextButton(
              onPressed: () => showMentorTourSheet(context),
              child: const Text('ouvrir'),
            ),
          ],
        ),
      ),
    );
    router = GoRouter(
      initialLocation: '/reglages',
      routes: [
        GoRoute(path: '/reglages', builder: (_, _) => page('réglages')),
        GoRoute(path: AppRoutes.home, builder: (_, _) => page('accueil')),
        GoRoute(path: AppRoutes.training, builder: (_, _) => page('séances')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mentorSpeakerProvider.overrideWithValue(_Muet())],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  String ici() => router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('la dernière étape propose de terminer, puis la fin', (
    tester,
  ) async {
    await ouvrir(tester, mentorTour.length - 1);
    expect(find.text('Étape 7 sur 7'), findsOneWidget);
    expect(find.text('Étape suivante'), findsNothing);

    await tester.tap(find.text('Terminer la visite'));
    await tester.pumpAndSettle();
    expect(find.text('7 espaces découverts'), findsOneWidget);
    expect(find.text('Visite terminée'), findsOneWidget);
  });

  testWidgets('« Revoir la visite » repart de la première étape', (
    tester,
  ) async {
    await ouvrir(tester, mentorTour.length);
    await tester.tap(find.text('Revoir la visite'));
    await tester.pumpAndSettle();
    expect(find.text('Étape 1 sur 7'), findsOneWidget);
    expect(find.text('L’accueil'), findsOneWidget);
  });

  testWidgets('« Revenir à l’accueil » ferme la feuille et y emmène', (
    tester,
  ) async {
    await ouvrir(tester, mentorTour.length);
    await tester.tap(find.text('Revenir à l’accueil'));
    await tester.pumpAndSettle();
    expect(find.byType(MentorTourCard), findsNothing);
    expect(ici(), AppRoutes.home);
  });

  testWidgets('« Voir l’entraînement » marque l’étape vue et y emmène', (
    tester,
  ) async {
    await ouvrir(tester, 1);
    await tester.tap(find.text('Voir l’entraînement'));
    await tester.pumpAndSettle();
    expect(find.byType(MentorTourCard), findsNothing);
    expect(ici(), AppRoutes.training);

    // Rouverte, la visite reprend APRÈS l'étape vue.
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Étape 3 sur 7'), findsOneWidget);
  });
}
