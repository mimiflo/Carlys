import 'dart:typed_data';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// LES PIÈCES de l'écran « Ajouter / Modifier ce repas », versées au design
/// system : ce que chacune promet, et qu'elle tient — la cible tactile, ce
/// qu'annonce le lecteur d'écran, et la tenue en grand texte sur 320 points.
void main() {
  Widget monte(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.dark(),
    home: Scaffold(
      body: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );

  group('AppAdaptiveGrid : autant de colonnes que la largeur en loge', () {
    int colonnes(double largeur, {int nombre = 4, double texte = 1}) =>
        AppAdaptiveGrid.columnsFor(
          width: largeur,
          minItemWidth: 64,
          spacing: 8,
          count: nombre,
          textScaler: TextScaler.linear(texte),
        );

    test(
      'quatre sur un téléphone, deux sur 320 points, une en grand texte',
      () {
        expect(colonnes(329), 4);
        expect(colonnes(256), 2);
        expect(colonnes(256, texte: 2), 1);
        expect(colonnes(329, texte: 2), 2);
      },
    );

    test('jamais d’orpheline : trois colonnes pour quatre deviennent deux', () {
      // 3 × 64 + 2 × 8 = 208 : trois tiendraient, mais la quatrième
      // resterait seule sur sa rangée.
      expect(colonnes(230), 2);
      expect(colonnes(230, nombre: 3), 3);
    });

    testWidgets('les cellules d’une rangée ont la même hauteur', (
      tester,
    ) async {
      await tester.pumpWidget(
        monte(
          const SizedBox(
            width: 300,
            child: AppAdaptiveGrid(
              minItemWidth: 64,
              children: [Text('Un'), Text('Deux lignes\nde texte')],
            ),
          ),
        ),
      );
      final hauteurs = [
        for (final cellule in find.byType(Expanded).evaluate())
          (cellule.renderObject! as RenderBox).size.height,
      ];
      expect(hauteurs.toSet(), hasLength(1));
    });
  });

  group('AppNutrientTile', () {
    testWidgets('une valeur inconnue s’écrit « — » et se dit « inconnu »', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        monte(
          const AppNutrientTile(
            icon: AppIcons.nutrientFat,
            tint: AppColors.nutritionFat,
            label: 'Lipides',
            unit: 'g',
            value: null,
          ),
        ),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing, reason: 'inconnu n’est pas zéro');
      expect(find.bySemanticsLabel('Lipides : inconnu'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('saisie : une case numérique, haute d’une cible tactile', (
      tester,
    ) async {
      final saisies = <String>[];
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        monte(
          SizedBox(
            width: 90,
            child: AppNutrientTile.editable(
              icon: AppIcons.nutrientEnergy,
              tint: AppColors.nutritionEnergy,
              label: 'Calories',
              unit: 'kcal',
              controller: controller,
              onChanged: saisies.add,
              errorText: 'Calories : entre 1 et 10 000.',
            ),
          ),
        ),
      );

      final champ = find.byType(TextField);
      expect(tester.getSize(champ).height, greaterThanOrEqualTo(48));
      expect(
        tester.widget<TextField>(champ).keyboardType,
        TextInputType.number,
      );
      await tester.enterText(champ, '380');
      expect(saisies, ['380']);
      // Hors bornes : le puits passe au rouge.
      final bord =
          tester.widget<TextField>(champ).decoration!.enabledBorder!
              as OutlineInputBorder;
      expect(bord.borderSide.color, AppColors.danger);
    });

    testWidgets('en faute : la case se DIT invalide, et dit pourquoi — pas '
        'seulement en rouge', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: '0');
      addTearDown(controller.dispose);
      Future<void> tuile(String? faute) => tester.pumpWidget(
        monte(
          SizedBox(
            width: 90,
            child: AppNutrientTile.editable(
              icon: AppIcons.nutrientEnergy,
              tint: AppColors.nutritionEnergy,
              label: 'Calories',
              unit: 'kcal',
              controller: controller,
              errorText: faute,
            ),
          ),
        ),
      );

      await tuile('Calories : entre 1 et 10 000.');
      final fautive = tester.getSemantics(find.byType(TextField));
      expect(
        fautive,
        isSemantics(isTextField: true, hint: 'Calories : entre 1 et 10 000.'),
      );
      expect(
        fautive.getSemanticsData().validationResult,
        SemanticsValidationResult.invalid,
      );

      await tuile(null);
      final juste = tester.getSemantics(find.byType(TextField));
      expect(juste.getSemanticsData().hint, isEmpty);
      expect(
        juste.getSemanticsData().validationResult,
        isNot(SemanticsValidationResult.invalid),
      );
      semantics.dispose();
    });
  });

  group('AppIconChoiceTile', () {
    testWidgets('un choix exclusif, choisi, qui répond sur toute la tuile', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var touches = 0;
      await tester.pumpWidget(
        monte(
          AppIconChoiceTile(
            icon: AppIcons.mealLunch,
            label: 'Déjeuner',
            selected: true,
            onTap: () => touches++,
          ),
        ),
      );

      final tuile = find.byType(AppIconChoiceTile);
      expect(tester.getSize(tuile).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(tuile),
        isSemantics(
          label: 'Déjeuner',
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(tuile);
      expect(touches, 1);
      semantics.dispose();
    });
  });

  group('AppChoicePills', () {
    List<AppChoice<String>> unites() => const [
      AppChoice('g', 'g', semanticLabel: 'grammes'),
      AppChoice('ml', 'ml', semanticLabel: 'millilitres'),
      AppChoice('portion', 'portion'),
    ];

    testWidgets('chaque pastille, même « g », est une cible tactile entière', (
      tester,
    ) async {
      final choisies = <String>[];
      await tester.pumpWidget(
        monte(
          AppChoicePills<String>(
            choices: unites(),
            selected: 'g',
            onSelected: choisies.add,
          ),
        ),
      );

      for (final boite
          in find
              .descendant(
                of: find.byType(AppChoicePills<String>),
                matching: find.byType(GestureDetector),
              )
              .evaluate()) {
        final taille = (boite.renderObject! as RenderBox).size;
        expect(taille.width, greaterThanOrEqualTo(48));
        expect(taille.height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('ml'));
      expect(choisies, ['ml']);
    });

    testWidgets('l’écart VISIBLE entre deux pastilles est partout le même', (
      tester,
    ) async {
      // Avant : « g » et « ml », plus étroits que le doigt, flottaient au
      // milieu de leur cible invisible, et l'écart vu variait d'une paire
      // à l'autre (le triple entre « g » et « ml » qu'entre « portion » et
      // « pièce »).
      await tester.pumpWidget(
        monte(
          AppChoicePills<String>(
            choices: [...unites(), const AppChoice('piece', 'pièce')],
            selected: 'g',
            onSelected: (_) {},
          ),
        ),
      );

      final pastilles =
          find
              .descendant(
                of: find.byType(AppChoicePills<String>),
                matching: find.byType(DecoratedBox),
              )
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget)))
              .toList()
            ..sort((a, b) => a.left.compareTo(b.left));
      expect(pastilles, hasLength(4));
      for (var i = 1; i < pastilles.length; i++) {
        expect(
          pastilles[i].left - pastilles[i - 1].right,
          moreOrLessEquals(AppSpacing.xxs),
          reason: 'écart entre les pastilles ${i - 1} et $i',
        );
      }
    });

    testWidgets('verrouillé : la valeur reste dite, rien ne répond', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final choisies = <String>[];
      await tester.pumpWidget(
        monte(
          AppChoicePills<String>(
            choices: unites(),
            selected: 'g',
            onSelected: null,
          ),
        ),
      );

      await tester.tap(find.text('ml'));
      expect(choisies, isEmpty);
      // L'abréviation se dit en toutes lettres, et l'état se dit aussi.
      expect(
        tester.getSemantics(find.bySemanticsLabel('grammes')),
        isSemantics(
          label: 'grammes',
          isButton: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: false,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('AppDashedButton', () {
    testWidgets('toute la largeur, une cible tactile, et éteint sans geste', (
      tester,
    ) async {
      var touches = 0;
      await tester.pumpWidget(
        monte(
          AppDashedButton(
            label: 'Ajouter un aliment',
            icon: AppIcons.addFood,
            onPressed: () => touches++,
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(AppDashedButton)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Ajouter un aliment'));
      expect(touches, 1);

      await tester.pumpWidget(
        monte(
          const AppDashedButton(
            label: 'Ajouter un aliment',
            icon: AppIcons.addFood,
            onPressed: null,
          ),
        ),
      );
      await tester.tap(find.text('Ajouter un aliment'), warnIfMissed: false);
      expect(touches, 1);
    });
  });

  group('AppThumbnail', () {
    testWidgets('sans photo : le dessin violet, jamais une case vide', (
      tester,
    ) async {
      var touches = 0;
      await tester.pumpWidget(
        monte(
          AppThumbnail(
            fallbackIcon: AppIcons.mealLunch,
            semanticLabel: 'Pas encore de photo du plat',
            action: AppThumbnailAction(
              icon: AppIcons.mealPhoto,
              tooltip: 'Ajouter une photo',
              onPressed: () => touches++,
            ),
          ),
        ),
      );

      expect(find.byIcon(AppIcons.mealLunch), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).gradient == AppColors.violetRamp,
        ),
        findsOneWidget,
      );
      // Le petit bouton rond répond sur une cible tactile entière, logée
      // dans l'angle de la vignette.
      final bouton = find.byTooltip('Ajouter une photo');
      expect(tester.getSize(bouton).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(bouton);
      expect(touches, 1);
    });
  });

  group('AppThumbnail, avec une photo', () {
    testWidgets('l’image au lieu du dessin ; pendant une préparation, '
        'l’indicateur et le bouton qui attend', (tester) async {
      final image = MemoryImage(Uint8List.fromList(const [1, 2, 3]));
      Widget vignette({required bool busy}) => monte(
        AppThumbnail(
          fallbackIcon: AppIcons.mealLunch,
          semanticLabel: 'Photo du plat',
          image: image,
          busy: busy,
          action: AppThumbnailAction(
            icon: AppIcons.mealPhoto,
            tooltip: 'Changer la photo',
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpWidget(vignette(busy: false));
      expect(tester.widget<Image>(find.byType(Image)).image, same(image));
      expect(find.byIcon(AppIcons.mealLunch), findsNothing);

      await tester.pumpWidget(vignette(busy: true));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byIcon(AppIcons.mealPhoto),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('AppScreenHeader.centered', () {
    Widget entete() => const AppScreenHeader.centered(
      title: 'Modifier ce repas',
      tagline: 'Ajuste les détails',
      actions: [SizedBox(width: 48, height: 48, key: Key('action'))],
    );

    testWidgets('le titre au centre, l’action à droite', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: Center(child: entete())),
        ),
      );

      final ecran = tester.getSize(find.byType(Scaffold)).width;
      expect(
        tester.getCenter(find.text('Modifier ce repas')).dx,
        closeTo(ecran / 2, 1),
      );
      expect(find.text('AJUSTE LES DÉTAILS'), findsOneWidget);
      expect(
        tester.getTopRight(find.byKey(const Key('action'))).dx,
        closeTo(ecran, 1),
      );
    });

    testWidgets('320 points, texte doublé : le titre passe dessous, entier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: SafeArea(child: entete())),
        ),
      );

      expect(tester.takeException(), isNull);
      // Sous l'action, et non plus entre deux boutons.
      expect(
        tester.getTopLeft(find.text('Modifier ce repas')).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const Key('action'))).dy),
      );
    });
  });

  group('AppTextField', () {
    testWidgets('l’unité dans la case, et la lecture seule qui ne pâlit pas', (
      tester,
    ) async {
      final controller = TextEditingController(text: '320');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        monte(
          AppTextField(
            label: 'Quantité (grammes)',
            controller: controller,
            suffixText: 'g',
            suffixIcon: AppIcons.editOutline,
            readOnly: true,
          ),
        ),
      );

      final champ = tester.widget<TextField>(find.byType(TextField));
      expect(champ.readOnly, isTrue);
      expect(champ.enabled, isNot(false), reason: 'lisible, pas désactivé');
      expect(find.text('g'), findsOneWidget);
      expect(find.byIcon(AppIcons.editOutline), findsOneWidget);
    });

    testWidgets('le libellé est celui du CHAMP pour le lecteur d’écran, lu '
        'avant sa valeur, et nulle part ailleurs', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: 'Poulet, riz, brocoli');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        monte(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Nom du repas',
                controller: controller,
                hint: 'Un indice',
              ),
              const Text('Un voisin'),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(TextField)),
        isSemantics(
          isTextField: true,
          label: 'Nom du repas',
          value: 'Poulet, riz, brocoli',
        ),
      );
      // Le texte visible au-dessus n'est pas un second nœud qui se lirait
      // détaché du champ.
      expect(find.bySemanticsLabel('Nom du repas'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('minLines 1, maxLines 3 : une ligne pour un nom court, le '
        'nom long passe à la ligne au lieu de se couper', (tester) async {
      final controller = TextEditingController(text: 'Skyr');
      addTearDown(controller.dispose);
      Widget champ() => monte(
        SizedBox(
          width: 200,
          child: AppTextField(
            label: 'Nom du repas',
            controller: controller,
            suffixIcon: AppIcons.editOutline,
            keyboardType: TextInputType.text,
            minLines: 1,
            maxLines: 3,
          ),
        ),
      );
      await tester.pumpWidget(champ());
      final court = tester.getSize(find.byType(EditableText)).height;

      controller.text = 'Poulet, riz, brocoli et haricots verts';
      await tester.pump();
      final long = tester.getSize(find.byType(EditableText)).height;

      expect(long, greaterThan(court * 1.5), reason: 'le nom s’enroule');
    });
  });

  testWidgets('showAppPrompt : le clavier numérique et l’unité', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppPrompt(
                context,
                title: 'Quantité de riz',
                initialValue: '150',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                suffixText: 'g',
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final champ = tester.widget<TextField>(find.byType(TextField));
    expect(
      champ.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    expect(find.text('g'), findsOneWidget);
  });

  group('AppButton.destructiveOutline', () {
    testWidgets('sombre : le contour rouge ; clair : l’aplat lisible', (
      tester,
    ) async {
      Widget bouton() => AppButton(
        label: 'Supprimer ce repas',
        variant: AppButtonVariant.destructiveOutline,
        onPressed: () {},
      );

      await tester.pumpWidget(monte(bouton()));
      expect(find.byType(OutlinedButton), findsOneWidget);

      await tester.pumpWidget(monte(bouton(), theme: AppTheme.light()));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  testWidgets('AppTitledCard : les pastilles passent sous le titre quand la '
      'rangée est trop courte', (tester) async {
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      monte(
        AppTitledCard(
          icon: AppIcons.mealQuantity,
          title: 'Quantité',
          trailing: AppChoicePills<String>(
            choices: const [
              AppChoice('g', 'g'),
              AppChoice('ml', 'ml'),
              AppChoice('portion', 'portion'),
              AppChoice('pièce', 'pièce'),
            ],
            selected: 'g',
            onSelected: (_) {},
          ),
          child: const Text('Contenu'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('pièce')).dy,
      greaterThan(tester.getBottomLeft(find.text('QUANTITÉ')).dy),
    );
  });

  testWidgets('AppTitledCard : le titre est UN nœud, et seul lui est un '
      'titre', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: '320');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      monte(
        AppTitledCard(
          icon: AppIcons.mealQuantity,
          title: 'Quantité',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Quantité (grammes)',
                controller: controller,
                readOnly: true,
              ),
              const Text('Calculé à partir des aliments.'),
            ],
          ),
        ),
      ),
    );

    // Le titre, seul dans son nœud…
    expect(
      tester.getSemantics(find.text('QUANTITÉ')),
      matchesSemantics(label: 'QUANTITÉ', isHeader: true),
    );
    // … et le champ n'est PAS un titre, ni ne lit le titre ou l'aide.
    expect(
      tester.getSemantics(find.byType(TextField)),
      isSemantics(
        isTextField: true,
        isHeader: false,
        label: 'Quantité (grammes)',
        value: '320',
      ),
    );
    final titres = [
      for (final node
          in find.semantics.byFlag(SemanticsFlag.isHeader).evaluate())
        node.label,
    ];
    expect(titres, ['QUANTITÉ']);
    semantics.dispose();
  });

  testWidgets('AppRoundIconButton désactivé : tamisé, et dit désactivé', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      monte(
        const AppRoundIconButton(
          icon: AppIcons.delete,
          tooltip: 'Supprimer ce repas',
          color: AppColors.danger,
          onPressed: null,
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(IconButton)),
      isSemantics(
        tooltip: 'Supprimer ce repas',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.delete)).color,
      AppColors.darkIconInactive,
    );
    semantics.dispose();
  });

  testWidgets('AppListRow : une ligne à la taille d’origine, le titre '
      'entier en texte agrandi', (tester) async {
    Future<RenderParagraph> titre(double echelle) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(echelle)),
          child: monte(
            SizedBox(
              width: 220,
              child: AppListRow(
                title: 'Choisir dans la galerie',
                leading: AppIcons.mealPhotoGallery,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      return tester.renderObject<RenderParagraph>(
        find.text('Choisir dans la galerie'),
      );
    }

    expect((await titre(1)).maxLines, 1);
    final agrandi = await titre(2);
    expect(agrandi.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
