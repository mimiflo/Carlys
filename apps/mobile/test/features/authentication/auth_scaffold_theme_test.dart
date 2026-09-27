import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/auth_brand_header.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce fichier défend : fond et textes des écrans AuthScaffold viennent
/// du MÊME thème. Un écran de MARQUE (`brand: true`) impose « Sombre » — le
/// fond des captures validées — à tout ce qu'il porte, même sous « Sombre
/// OLED » ; un écran utilitaire suit le thème choisi. Jamais l'un sans
/// l'autre.
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

  testWidgets('écran de marque : le fond des captures, même sous l’OLED', (
    tester,
  ) async {
    await pump(tester, theme: AppTheme.oledDark(), brand: true);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.darkBackground);
    expect(titleColor(tester), AppTheme.dark().textTheme.headlineMedium?.color);
  });

  testWidgets('écran utilitaire : il SUIT le thème OLED, fond compris', (
    tester,
  ) async {
    await pump(tester, theme: AppTheme.oledDark(), brand: false);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.oledBackground);
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
    Color? seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.oledDark(),
        home: AuthScaffold(
          title: 'Titre témoin',
          brand: true,
          children: [
            Builder(
              builder: (context) {
                seen = Theme.of(context).scaffoldBackgroundColor;
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );

    expect(seen, AppColors.darkBackground);
  });

  testWidgets('sous la signature, le bloc court se centre verticalement', (
    tester,
  ) async {
    // Demande produit : rien de collé en haut — le titre et le formulaire
    // se centrent dans l'espace RESTANT, à marges hautes et basses égales.
    await pump(tester, theme: AppTheme.dark(), brand: true);

    final zone = tester.getRect(find.byType(SingleChildScrollView));
    final bloc = tester.getRect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byWidgetPredicate(
          (w) => w is Column && w.mainAxisSize == MainAxisSize.min,
        ),
      ),
    );
    final haut = bloc.top - zone.top - AppSpacing.md;
    final bas = zone.bottom - AppSpacing.md - bloc.bottom;

    expect(haut, greaterThan(0), reason: 'le bloc ne colle pas à la signature');
    expect(
      (haut - bas).abs(),
      lessThan(1.0),
      reason: 'marges haute et basse égales : le bloc est centré',
    );
  });

  testWidgets('la signature ne bouge pas quand le contenu s’allonge', (
    tester,
  ) async {
    // La cohérence demandée : le logo au même niveau sur la connexion
    // (contenu court) et l'inscription (contenu long) — le centrage ne
    // concerne que ce qui vit SOUS la signature, jamais elle.
    Future<double> niveau(double hauteurContenu) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: AuthScaffold(
            title: 'Titre témoin',
            brand: true,
            children: [SizedBox(height: hauteurContenu)],
          ),
        ),
      );
      return tester.getTopLeft(find.byType(AuthBrandHeader)).dy;
    }

    final court = await niveau(10);
    final long = await niveau(2000);
    expect(court, long);
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
}
