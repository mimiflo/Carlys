import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
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
}
