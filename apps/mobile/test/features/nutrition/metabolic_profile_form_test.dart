import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/metabolic_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : le bouton « Enregistrer mon profil » ne fait
/// jamais semblant.
///
/// Dans le PATCH du profil, une valeur absente veut dire « inchangée », pas
/// « supprimée ». Effacer sa taille puis enregistrer semblait donc marcher :
/// le bouton tournait, aucune erreur ne s'affichait, et l'ancienne valeur
/// revenait à la réouverture — sans un mot d'explication.
void main() {
  Future<void> monter(WidgetTester tester, MetabolicProfile profile) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MetabolicProfileForm(profile: profile),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> enregistrer(WidgetTester tester) async {
    final bouton = find.text('Enregistrer mon profil');
    await tester.ensureVisible(bouton);
    await tester.tap(bouton);
    await tester.pumpAndSettle();
  }

  testWidgets('vider sa taille le DIT, au lieu de ne rien faire', (
    tester,
  ) async {
    await monter(
      tester,
      const MetabolicProfile(
        sex: BiologicalSex.male,
        heightCm: 178,
        activityLevel: ActivityLevel.moderate,
        goal: NutritionGoal.maintain,
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '');
    await enregistrer(tester);

    expect(
      find.textContaining('se corrige, elle ne se retire pas'),
      findsOneWidget,
    );
  });

  testWidgets('un formulaire entièrement vide le dit aussi', (tester) async {
    await monter(tester, const MetabolicProfile());

    await enregistrer(tester);

    expect(
      find.textContaining('Renseigne au moins une valeur'),
      findsOneWidget,
    );
  });
}
