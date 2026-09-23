import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les onglets segmentés : chaque onglet répond sur toute sa hauteur, se dit
/// sélectionné ou non, et son compte se lit en mots.
void main() {
  Widget monte({
    required int selected,
    required ValueChanged<int> onSelected,
    int pending = 0,
  }) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: AppSegmentedTabs(
            segments: [
              const AppSegment('Défis'),
              const AppSegment('Ligue'),
              AppSegment('Amis', count: pending),
            ],
            selectedIndex: selected,
            onSelected: onSelected,
          ),
        ),
      ),
    ),
  );

  testWidgets('taper un onglet le choisit', (tester) async {
    final choisis = <int>[];
    await tester.pumpWidget(monte(selected: 0, onSelected: choisis.add));

    await tester.tap(find.text('Ligue'));
    await tester.pumpAndSettle();

    expect(choisis, [1]);
  });

  testWidgets('chaque onglet est une vraie cible tactile', (tester) async {
    await tester.pumpWidget(monte(selected: 0, onSelected: (_) {}));

    for (final label in ['Défis', 'Ligue', 'Amis']) {
      final zone = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(zone).height,
        greaterThanOrEqualTo(AppSpacing.touchTarget),
        reason: label,
      );
    }
  });

  testWidgets('le lecteur d’écran entend l’onglet choisi, sa place, et le '
      'compte en mots', (tester) async {
    final semantics = tester.ensureSemantics();
    final choisis = <int>[];
    await tester.pumpWidget(
      monte(selected: 1, onSelected: choisis.add, pending: 2),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Ligue')),
      matchesSemantics(
        label: 'Ligue',
        hint: 'Onglet 2 sur 3',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    // Une pastille « 2 » ne dit rien à qui ne la voit pas.
    expect(find.bySemanticsLabel('Amis, 2 en attente'), findsOneWidget);

    // L'étiquette est réécrite : le geste doit survivre à l'exclusion.
    tester.semantics.tap(find.semantics.byLabel('Amis, 2 en attente'));
    expect(choisis, [2]);
    semantics.dispose();
  });

  testWidgets('aucun compte, aucune pastille ; au-delà de 99, « 99+ »', (
    tester,
  ) async {
    await tester.pumpWidget(monte(selected: 0, onSelected: (_) {}));
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(
      monte(selected: 0, onSelected: (_) {}, pending: 140),
    );
    expect(find.text('99+'), findsOneWidget);
  });
}
