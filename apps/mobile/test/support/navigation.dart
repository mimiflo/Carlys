/// Navigation de la réorganisation en CINQ onglets (août 2026).
///
/// Les écrans qui étaient des onglets — exercices, coach, nutrition, profil —
/// se joignent désormais en deux gestes : l'onglet porteur, puis la carte du
/// hub. Ces aides encodent le parcours UNE fois ; si l'architecture bouge,
/// c'est ici qu'elle bouge.
library;

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AppBottomBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Ouvre la bibliothèque d'exercices : Training → carte « Exercices ».
Future<void> openExerciseLibrary(WidgetTester tester) async {
  await tapTab(tester, 'Training');
  await tester.tap(find.text('Exercices'));
  await tester.pumpAndSettle();
}

/// Ouvre le coach : Training → carte « Coach IA ».
Future<void> openCoach(WidgetTester tester) async {
  await tapTab(tester, 'Training');
  await tester.tap(find.text('Coach IA'));
  await tester.pumpAndSettle();
}

/// Ouvre la nutrition : son propre onglet depuis septembre 2026.
///
/// Elle était une carte à ouvrir depuis Academy. Le chemin passe par ce
/// helper précisément pour que ce genre de déplacement se règle ICI, en un
/// endroit, et non dans chaque test qui a besoin de l'écran.
Future<void> openNutrition(WidgetTester tester) async {
  await tapTab(tester, 'Nutrition');
}

/// Ouvre le profil : l'avatar de l'accueil — l'onglet Profil n'existe plus.
///
/// L'avatar se repère par l'étiquette de son `Semantics` (côté WIDGET, pas
/// arbre de sémantique : les tests ne posent pas de `SemanticsHandle`, donc
/// `find.bySemanticsLabel` ne verrait rien).
Future<void> openProfile(WidgetTester tester) async {
  await tapTab(tester, 'Accueil');
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label ?? '').startsWith('Profil'),
    ),
  );
  await tester.pumpAndSettle();
}

/// Ouvre les RÉGLAGES : le profil, puis son rouage.
///
/// Depuis la refonte du profil (septembre 2026), les réglages ne vivent plus
/// à même le profil — qui raconte — mais derrière le rouage de son en-tête.
Future<void> openProfileSettings(WidgetTester tester) async {
  await openProfile(tester);
  await tester.tap(find.byTooltip('Réglages'));
  await tester.pumpAndSettle();
}
