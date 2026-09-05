import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/carlys_profile_card.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/profile_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les illustrations de profil font 800 × 598 pixels pour une case de 116
/// points : décodées entières, quatre cartes coûtaient 7,5 Mo de cache image.
/// Le décodage suit la case et la densité de l'écran, comme les photos
/// d'exercices le font déjà.
void main() {
  testWidgets('l’illustration se décode à la taille de sa case',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: CarlysProfileCard(
            profile: CarlysProfile.constructeur,
            isCurrent: false,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Le fond flouté ET le premier plan : les deux partagent le décodage.
    final images = tester.widgetList<Image>(
      find.descendant(
        of: find.byType(CarlysProfileCard),
        matching: find.byType(Image),
      ),
    );
    expect(images, hasLength(2));
    for (final image in images) {
      final provider = image.image;
      expect(provider, isA<ResizeImage>());
      expect(
        (provider as ResizeImage).width,
        (ProfileIllustration.imageWidth * 3).round(),
      );
    }
  });
}
