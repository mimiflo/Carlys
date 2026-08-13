import 'dart:convert';
import 'dart:io';

import 'package:carlys_mobile/features/academy/data/academy_pack.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le pack d'apprentissage embarqué : chargement, validité, et reprise
/// après échec.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetAcademyPackCache);
  tearDown(resetAcademyPackCache);

  test('le pack se charge et chaque leçon est complète', () async {
    final lessons = await loadAcademyPack();

    expect(lessons, isNotEmpty);
    for (final lesson in lessons) {
      expect(lesson.title, isNotEmpty, reason: lesson.id);
      expect(lesson.body, isNotEmpty, reason: lesson.id);
      expect(lesson.question.choices.length, greaterThanOrEqualTo(2));
      expect(
        lesson.question.answerIndex,
        inInclusiveRange(0, lesson.question.choices.length - 1),
        reason: lesson.id,
      );
      expect(lesson.question.explanation, isNotEmpty, reason: lesson.id);
    }
    // Chaque catégorie de l'énumération a au moins une leçon : l'écran
    // n'affiche jamais d'en-tête de section orphelin, et l'ajout d'une
    // catégorie sans contenu se voit ici.
    for (final category in AcademyCategory.values) {
      expect(
        lessons.where((lesson) => lesson.category == category),
        isNotEmpty,
        reason: 'catégorie sans leçon : ${category.name}',
      );
    }
  });

  test('les identifiants de leçons sont uniques', () async {
    final lessons = await loadAcademyPack();
    final ids = lessons.map((lesson) => lesson.id).toSet();
    expect(ids.length, lessons.length);
  });

  test('chaque leçon porte son essentiel : points, illustration déclarée',
      () async {
    final lessons = await loadAcademyPack();
    for (final lesson in lessons) {
      expect(lesson.points, isNotEmpty, reason: lesson.id);
      expect(lesson.points.length, lessThanOrEqualTo(4), reason: lesson.id);
      expect(
        lesson.image,
        startsWith('assets/academy/'),
        reason: lesson.id,
      );
    }
  });

  test('l’anatomie couvre les 12 groupes du catalogue, sans slug inventé',
      () async {
    // Les slugs de référence viennent du catalogue de démonstration —
    // généré depuis le seed de l'API : la même vérité que la bibliothèque.
    final catalog = jsonDecode(
      File('assets/demo/catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final knownSlugs = (catalog['muscleGroups'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((group) => group['slug'] as String)
        .toSet();

    final lessons = await loadAcademyPack();
    final taughtSlugs = <String>{};
    for (final lesson in lessons) {
      for (final slug in lesson.muscleGroupSlugs) {
        expect(
          knownSlugs,
          contains(slug),
          reason: '${lesson.id} enseigne un groupe inconnu : $slug',
        );
        taughtSlugs.add(slug);
      }
    }

    // Chaque muscle du catalogue a sa fiche : personne n'apprend « presque
    // tout » le corps.
    final anatomy =
        lessons.where((lesson) => lesson.category == AcademyCategory.anatomie);
    expect(taughtSlugs, knownSlugs);
    for (final lesson in anatomy) {
      expect(lesson.muscleGroupSlugs, isNotEmpty, reason: lesson.id);
    }
  });

  test('un échec de lecture ne condamne pas les rechargements suivants',
      () async {
    // Simule un bundle sans l'asset : le premier chargement échoue.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async => null);
    await expectLater(loadAcademyPack(), throwsA(isA<Object>()));

    // Le bundle redevient normal : le rechargement doit RÉESSAYER, pas
    // resservir la future en échec restée mémoïsée.
    messenger.setMockMessageHandler('flutter/assets', null);
    final lessons = await loadAcademyPack();
    expect(lessons, isNotEmpty);
  });
}
