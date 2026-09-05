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

/// Ouvre la nutrition : Academy → carte « Nutrition ».
Future<void> openNutrition(WidgetTester tester) async {
  await tapTab(tester, 'Academy');
  await tester.tap(find.text('Nutrition'));
  await tester.pumpAndSettle();
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
