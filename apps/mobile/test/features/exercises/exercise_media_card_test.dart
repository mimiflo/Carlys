import 'package:carlys_mobile/core/media/remote_image.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercises_repository.dart';

/// La carte photo de la fiche : « Voir le mouvement » ne se promet QUE si une
/// photo existe — le catalogue n'a pas de vidéo, et la plupart des
/// mouvements n'ont pas encore de photo.
void main() {
  Future<void> monter(WidgetTester tester, {String? imageUrl}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [remoteImageProvider.overrideWith((ref, url) async => null)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ExerciseMediaCard(
              exercise: detailOf(
                summary('id-1', 'Squat', group: 'quadri', imageUrl: imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('sans photo : la carte reste, sans « Voir le mouvement »', (
    tester,
  ) async {
    await monter(tester);
    expect(find.byType(ExerciseMediaCard), findsOneWidget);
    expect(find.text('Voir le mouvement'), findsNothing);
  });

  testWidgets('avec photo : « Voir le mouvement » l’ouvre en grand', (
    tester,
  ) async {
    await monter(tester, imageUrl: 'https://cdn.test/squat.webp');
    expect(find.text('Voir le mouvement'), findsOneWidget);

    await tester.tap(find.text('Voir le mouvement'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
