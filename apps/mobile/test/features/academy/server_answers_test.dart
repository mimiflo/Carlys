import 'package:carlys_mobile/features/academy/data/answered_lessons_store.dart';
import 'package:carlys_mobile/features/academy/presentation/controllers/academy_controllers.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_community_repository.dart';

/// La relecture serveur des réponses : elle COMBLE le magasin local, elle
/// ne le réécrit jamais — la progression survit au changement d'appareil
/// sans qu'un serveur puisse jamais contredire ce que l'appareil a vu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCommunityRepository community;
  late ProviderContainer container;

  ProviderContainer monter() {
    community = FakeCommunityRepository();
    final container = ProviderContainer(
      overrides: [communityRepositoryProvider.overrideWithValue(community)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Map<String, int>> locales() => const AnsweredLessonsStore().read();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    container = monter();
  });

  test('les réponses d’un autre appareil comblent le magasin local', () async {
    community.remoteQuizAnswers = {'nutrition-proteines': 1, 'cardio-dose': 0};

    await container.read(academyActionsProvider).pullAnswers();

    expect(await locales(), {'nutrition-proteines': 1, 'cardio-dose': 0});
  });

  test('une réponse locale n’est JAMAIS réécrite par le serveur', () async {
    SharedPreferences.setMockInitialValues(const {
      AnsweredLessonsStore.key: '{"nutrition-proteines":0}',
    });
    community.remoteQuizAnswers = {'nutrition-proteines': 2};

    await container.read(academyActionsProvider).pullAnswers();

    expect(
      await locales(),
      {'nutrition-proteines': 0},
      reason: 'Le choix AFFICHÉ doit rester celui réellement fait ici.',
    );
  });

  test(
    'une réponse d’avant la migration (choix inconnu) est ignorée',
    () async {
      // Afficher un choix inventé mentirait sur ce qui a été coché : on
      // attend de savoir, plutôt que d'affirmer.
      community.remoteQuizAnswers = {'lecon-ancienne': null, 'cardio-dose': 2};

      await container.read(academyActionsProvider).pullAnswers();

      expect(await locales(), {'cardio-dose': 2});
    },
  );

  test('hors ligne : rien ne se passe, rien n’échoue', () async {
    community
      ..remoteQuizAnswers = {'cardio-dose': 1}
      ..offline = true;

    await container.read(academyActionsProvider).pullAnswers();

    expect(await locales(), isEmpty);
  });

  test(
    'le provider des réponses est rafraîchi quand un trou est comblé',
    () async {
      // Sans l'invalidation, l'écran resterait sur l'état d'avant la
      // relecture jusqu'à la prochaine navigation.
      final avant = await container.read(answeredLessonsProvider.future);
      expect(avant, isEmpty);

      community.remoteQuizAnswers = {'cardio-dose': 1};
      await container.read(academyActionsProvider).pullAnswers();

      final apres = await container.read(answeredLessonsProvider.future);
      expect(apres, {'cardio-dose': 1});
    },
  );

  test('la réponse donnée ICI part au serveur avec son choix', () async {
    await container
        .read(academyActionsProvider)
        .answer(lessonId: 'cardio-dose', choiceIndex: 2, correct: false);

    expect(community.quizChoices, {'cardio-dose': 2});
  });
}
