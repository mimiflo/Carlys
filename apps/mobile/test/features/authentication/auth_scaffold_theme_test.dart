import 'dart:async';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/auth_brand_header.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce fichier défend : la LISIBILITÉ des écrans AuthScaffold dans les
/// DEUX thèmes — le réglage « Clair » existe vraiment.
///
/// Le gabarit forçait le fond sombre pendant que titre et champs suivaient le
/// thème ambiant : en clair, titre quasi noir sur fond quasi noir. La règle
/// désormais gardée ici : un écran de MARQUE (`brand: true`) impose le thème
/// sombre à tout ce qu'il porte — fond ET textes ensemble ; un écran
/// utilitaire suit le thème ambiant — fond ET textes ensemble. Jamais l'un
/// sans l'autre.
void main() {
  setUp(() {
    // La connexion porte le cœur de la marque en décor — une scène ambiante
    // qui ne s'arrête jamais d'elle-même. La réduction d'animations la met
    // en pause (comportement réel d'accessibilité), et pumpAndSettle
    // converge.
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

  Future<void> pump(
    WidgetTester tester, {
    required ThemeData theme,
    required bool brand,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: AuthScaffold(
          title: 'Titre témoin',
          subtitle: 'Sous-titre témoin',
          brand: brand,
          children: const [SizedBox.shrink()],
        ),
      ),
    );
  }

  Color? titleColor(WidgetTester tester) =>
      tester.widget<Text>(find.text('Titre témoin')).style?.color;

  testWidgets('écran de marque : sombre, même sous le réglage clair', (
    tester,
  ) async {
    await pump(tester, theme: AppTheme.light(), brand: true);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.darkBackground);
    // Le titre vient du thème SOMBRE, pas du thème ambiant : clair sur fond
    // sombre, comme sur les captures validées.
    expect(titleColor(tester), AppTheme.dark().textTheme.headlineMedium?.color);
  });

  testWidgets('écran utilitaire : il SUIT le thème clair, fond compris', (
    tester,
  ) async {
    await pump(tester, theme: AppTheme.light(), brand: false);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.lightBackground);
    expect(
      titleColor(tester),
      AppTheme.light().textTheme.headlineMedium?.color,
    );
  });

  testWidgets('écran utilitaire en sombre : rien ne change pour lui', (
    tester,
  ) async {
    await pump(tester, theme: AppTheme.dark(), brand: false);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.darkBackground);
    expect(titleColor(tester), AppTheme.dark().textTheme.headlineMedium?.color);
  });

  testWidgets('le thème imposé atteint les ENFANTS de l’écran de marque', (
    tester,
  ) async {
    // Fond et titre viennent du gabarit lui-même : un mutant qui retirerait
    // le Theme() imposé les laisserait justes et ne casserait que les
    // enfants qui lisent Theme.of — c'est donc EUX que ce test regarde.
    Brightness? seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AuthScaffold(
          title: 'Titre témoin',
          brand: true,
          children: [
            Builder(
              builder: (context) {
                seen = Theme.of(context).brightness;
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );

    expect(seen, Brightness.dark);
  });

  testWidgets('le bloc court se centre verticalement dans l’écran', (
    tester,
  ) async {
    // Demande produit : rien de collé en haut — un contenu plus court que
    // l'écran se centre, à marges hautes et basses égales.
    await pump(tester, theme: AppTheme.dark(), brand: true);

    final bloc = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Column && w.crossAxisAlignment == CrossAxisAlignment.stretch,
      ),
    );
    final ecran = tester.view.physicalSize / tester.view.devicePixelRatio;
    final haut = bloc.top - AppSpacing.md;
    final bas = ecran.height - AppSpacing.md - bloc.bottom;

    expect(haut, greaterThan(0), reason: 'le bloc ne colle pas en haut');
    expect(
      (haut - bas).abs(),
      lessThan(1.0),
      reason: 'marges haute et basse égales : le bloc est centré',
    );
  });

  testWidgets('la signature se pose au même niveau, avec ou sans retour', (
    tester,
  ) async {
    // Le chevron n'existe que sur les écrans dépilables : sans réservation
    // de sa place, la signature de la connexion (premier écran) montait
    // d'une ligne par rapport à celle de l'inscription.
    final screen = AuthScaffold(
      title: 'Titre témoin',
      brand: true,
      children: const [SizedBox.shrink()],
    );

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: screen));
    expect(find.byIcon(AppIcons.back), findsNothing);
    final sansRetour = tester.getTopLeft(find.byType(AuthBrandHeader)).dy;

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const Scaffold()),
    );
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(MaterialPageRoute<void>(builder: (_) => screen)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.back), findsOneWidget);
    final avecRetour = tester.getTopLeft(find.byType(AuthBrandHeader)).dy;

    expect(sansRetour, avecRetour);
  });

  testWidgets('connexion RÉELLE en clair : la ligne de bascule reste claire', (
    tester,
  ) async {
    // Le défaut vécu : « Pas encore de compte ? » stylé depuis le contexte
    // de l'ÉCRAN — au-dessus du thème imposé — sortait gris sombre (2,79:1)
    // sur le fond sombre quand le réglage clair était actif.
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
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final prompt = tester.widget<Text>(find.text('Pas encore de compte ?'));
    expect(
      prompt.style?.color,
      AppTheme.dark().textTheme.bodySmall?.color,
      reason: 'le style doit se résoudre SOUS le thème de marque imposé',
    );
  });
}
