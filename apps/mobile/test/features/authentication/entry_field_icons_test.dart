import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce fichier défend : le ROSE CLAIR des icônes de champ des écrans
/// d'entrée (demande produit) — enveloppe, cadenas, personne, sur les DEUX
/// écrans réels, pas sur un champ isolé.
void main() {
  setUp(() {
    // Le cœur de la marque anime les deux écrans : la réduction
    // d'animations le met en pause et pumpAndSettle converge.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.production,
              apiBaseUrl: 'https://api.exemple.test',
              publicWebBaseUrl: 'https://web.exemple.test',
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color? couleur(WidgetTester tester, IconData icone) =>
      tester.widget<Icon>(find.byIcon(icone)).color;

  testWidgets('connexion : enveloppe et cadenas en rose clair', (tester) async {
    await pump(tester, const LoginScreen());

    expect(couleur(tester, AppIcons.mail), AppColors.fieldIcon);
    expect(couleur(tester, AppIcons.lock), AppColors.fieldIcon);
  });

  testWidgets('inscription : personne, enveloppe et cadenas en rose clair', (
    tester,
  ) async {
    await pump(tester, const RegisterScreen());

    expect(couleur(tester, AppIcons.personOutline), AppColors.fieldIcon);
    expect(couleur(tester, AppIcons.mail), AppColors.fieldIcon);
    expect(couleur(tester, AppIcons.lock), AppColors.fieldIcon);
  });
}
