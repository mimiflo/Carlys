import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE LIEN D'ACTION (« Voir mes mesures › », « Voir le parcours › ») : un
/// libellé violet suivi de son chevron, qui ouvre une suite d'un appui.
void main() {
  Widget monte(VoidCallback onPressed) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Center(
        child: AppLinkButton(label: 'Voir le parcours', onPressed: onPressed),
      ),
    ),
  );

  testWidgets('le chevron suit le libellé, tous deux en violet clair', (
    tester,
  ) async {
    await tester.pumpWidget(monte(() {}));

    final libelle = tester.getRect(find.text('Voir le parcours'));
    final chevron = tester.getRect(find.byIcon(AppIcons.chevronRight));
    expect(chevron.left, greaterThanOrEqualTo(libelle.right));

    final style = tester
        .widget<TextButton>(find.byType(TextButton))
        .style!
        .foregroundColor!
        .resolve({});
    expect(style, AppColors.primaryLight);
  });

  testWidgets('un appui ouvre la suite, et la cible garde sa hauteur '
      'tactile malgré l’absence de marge', (tester) async {
    var appuis = 0;
    await tester.pumpWidget(monte(() => appuis++));

    await tester.tap(find.byIcon(AppIcons.chevronRight));
    expect(appuis, 1);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
  });

  testWidgets('le lecteur d’écran entend un bouton nommé par son libellé', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(monte(() {}));

    expect(
      tester.getSemantics(find.byType(TextButton)),
      matchesSemantics(
        label: 'Voir le parcours',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    semantics.dispose();
  });
}
