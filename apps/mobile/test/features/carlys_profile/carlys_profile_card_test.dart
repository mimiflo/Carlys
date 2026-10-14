import 'dart:io';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/carlys_profile_card.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/carlys_profile_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La carte d'un profil : le profil retenu porte sa coche et SON libellé
/// (« Ton profil » dans les réglages, « Sélectionné » à l'onboarding), les
/// autres le chevron ; et chaque médaillon existe bien dans les assets.
void main() {
  Future<void> poser(WidgetTester tester, Widget carte) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: carte),
    ),
  );

  testWidgets('le profil retenu dit « Ton profil », sans chevron', (
    tester,
  ) async {
    await poser(
      tester,
      CarlysProfileCard(
        profile: CarlysProfile.stratege,
        isCurrent: true,
        onTap: () {},
      ),
    );
    expect(find.text('Ton profil'), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    expect(find.byIcon(AppIcons.chevronRight), findsNothing);
    // Un seul nœud : nom ET description, état retenu, et le geste — sans
    // lui, TalkBack ou Switch Access ne pourraient pas choisir un profil.
    expect(
      tester.getSemantics(find.byType(CarlysProfileCard)),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isSelected: true,
        label:
            'Le Stratège. Apprendre avant d’agir. Comprendre pour optimiser '
            'chaque décision.',
      ),
    );
  });

  testWidgets('à l’onboarding, la carte retenue dit « Sélectionné »', (
    tester,
  ) async {
    await poser(
      tester,
      CarlysProfileCard(
        profile: CarlysProfile.athlete,
        isCurrent: true,
        selectedLabel: 'Sélectionné',
        onTap: () {},
      ),
    );
    expect(find.text('Sélectionné'), findsOneWidget);
    expect(find.text('Ton profil'), findsNothing);
  });

  testWidgets('une carte non retenue porte le chevron et répond au toucher', (
    tester,
  ) async {
    var touches = 0;
    await poser(
      tester,
      CarlysProfileCard(
        profile: CarlysProfile.challenger,
        isCurrent: false,
        onTap: () => touches++,
      ),
    );
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
    expect(find.text('Ton profil'), findsNothing);
    await tester.tap(find.byType(CarlysProfileCard));
    expect(touches, 1);
  });

  test('chaque médaillon est livré', () {
    // Le repli (disque + icône) existe, mais un médaillon manquant serait
    // une régression silencieuse : le fichier doit être là.
    for (final profile in CarlysProfile.values) {
      final asset = carlysProfileContentOf(profile).assetPath;
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });
}
