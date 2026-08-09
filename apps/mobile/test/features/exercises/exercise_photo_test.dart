import 'dart:typed_data';

import 'package:carlys_mobile/core/media/remote_image.dart';
import 'package:carlys_mobile/core/media/remote_image_cache.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_media_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercises_repository.dart';

/// PNG 1×1 valide (voir test/core/remote_image_test.dart).
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
]);

class _Cache implements RemoteImageCache {
  _Cache({this.available = true});

  final bool available;
  final List<String> asked = [];

  @override
  Future<Uint8List?> bytesOf(String url) async {
    asked.add(url);
    return available ? _png : null;
  }
}

Future<void> _pump(WidgetTester tester, _Cache cache, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [remoteImageCacheProvider.overrideWithValue(cache)],
      child: MaterialApp(
        home: Scaffold(backgroundColor: AppColors.darkBackground, body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Les photos d'exercices viennent de l'administration, pas du bundle : elles
/// manquent souvent, et leur absence est un cas NORMAL — jamais une erreur.
void main() {
  testWidgets('carte : la photo rattachée est chargée depuis son URL',
      (tester) async {
    final cache = _Cache();

    await _pump(
      tester,
      cache,
      ExerciseCard(
        exercise: summary(
          'id-1',
          'Squat',
          imageUrl: 'http://storage.test/carlys-media/image/abc.webp',
        ),
        onTap: () {},
      ),
    );

    expect(cache.asked, ['http://storage.test/carlys-media/image/abc.webp']);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('carte sans photo : vignette de marque, aucun appel réseau',
      (tester) async {
    final cache = _Cache();

    await _pump(
      tester,
      cache,
      ExerciseCard(exercise: summary('id-1', 'Squat'), onTap: () {}),
    );

    expect(cache.asked, isEmpty);
    expect(find.byIcon(AppIcons.workout), findsOneWidget);
  });

  testWidgets('carte hors ligne : la vignette de marque reprend la main',
      (tester) async {
    await _pump(
      tester,
      _Cache(available: false),
      ExerciseCard(
        exercise: summary('id-1', 'Squat', imageUrl: 'http://s/image/a.webp'),
        onTap: () {},
      ),
    );

    expect(find.byIcon(AppIcons.workout), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fiche : l’en-tête affiche la photo, titre inchangé',
      (tester) async {
    final cache = _Cache();
    final exercise = detailOf(
      summary(
        'id-1',
        'Squat',
        group: 'quadriceps',
        imageUrl: 'http://s/image/squat.webp',
      ),
    );

    await _pump(tester, cache, ExerciseMediaHeader(exercise: exercise));

    expect(cache.asked, ['http://s/image/squat.webp']);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('fiche sans photo : le placeholder garde la même forme',
      (tester) async {
    final exercise = detailOf(summary('id-1', 'Squat', group: 'quadriceps'));

    await _pump(tester, _Cache(), ExerciseMediaHeader(exercise: exercise));

    expect(find.byIcon(AppIcons.workout), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ExerciseMediaHeader)).height,
      ExerciseMediaHeader.height,
    );
  });
}
