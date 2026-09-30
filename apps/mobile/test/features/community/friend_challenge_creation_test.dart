import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/domain/entities/friend_challenge.dart';
import 'package:carlys_mobile/features/community/presentation/providers/community_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_community_repository.dart';

/// RELANCER UN DÉFI APRÈS UNE RÉPONSE PERDUE NE LE CRÉE PAS DEUX FOIS.
///
/// Le serveur écrit le défi et invite les amis, puis la réponse se perd :
/// l'écran dit « réessaie ». L'identifiant était tiré à CHAQUE appel : le
/// nouvel essai posait un second défi, et chaque ami recevait deux
/// invitations. Le serveur est pourtant idempotent par identifiant.
void main() {
  const brouillon = NewFriendChallenge(
    title: 'Cinq séances',
    metric: ChallengeMetric.workouts,
    durationDays: 7,
    invitedUserIds: ['ami-1', 'ami-2'],
    message: 'On y va ?',
  );

  late _ReponsePerdue repository;
  late ProviderContainer container;

  setUp(() {
    repository = _ReponsePerdue();
    container = ProviderContainer(
      overrides: [communityRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  CommunityActions actions() => container.read(communityActionsProvider);

  test('le MÊME brouillon relancé rejoue le même identifiant', () async {
    repository.perdreLaReponse = true;
    await expectLater(
      actions().createFriendChallenge(brouillon),
      throwsA(isA<NetworkException>()),
    );
    // Le brouillon reste, pour rouvrir la feuille pré-remplie.
    expect(actions().pendingFriendChallenge, brouillon);

    repository.perdreLaReponse = false;
    await actions().createFriendChallenge(
      // Un brouillon ÉGAL, pas le même objet : c'est ce que rend la feuille.
      const NewFriendChallenge(
        title: 'Cinq séances',
        metric: ChallengeMetric.workouts,
        durationDays: 7,
        invitedUserIds: ['ami-1', 'ami-2'],
        message: 'On y va ?',
      ),
    );

    expect(repository.ids, hasLength(2));
    expect(repository.ids.toSet(), hasLength(1));
    // Un seul défi côté serveur : le rejeu est retombé dessus.
    expect(repository.friendChallengeList, hasLength(1));
    expect(actions().pendingFriendChallenge, isNull);
  });

  test('un brouillon DIFFÉRENT est un autre geste', () async {
    repository.perdreLaReponse = true;
    await expectLater(
      actions().createFriendChallenge(brouillon),
      throwsA(isA<NetworkException>()),
    );
    repository.perdreLaReponse = false;

    await actions().createFriendChallenge(
      const NewFriendChallenge(
        title: 'Dix séances',
        metric: ChallengeMetric.workouts,
        durationDays: 7,
        invitedUserIds: ['ami-1', 'ami-2'],
      ),
    );

    expect(repository.ids.toSet(), hasLength(2));
  });

  test('les mêmes amis recochés dans un autre ordre : même geste', () async {
    repository.perdreLaReponse = true;
    await expectLater(
      actions().createFriendChallenge(brouillon),
      throwsA(isA<NetworkException>()),
    );
    repository.perdreLaReponse = false;

    // Décocher puis recocher « ami-1 » le repousse en fin de liste.
    await actions().createFriendChallenge(
      const NewFriendChallenge(
        title: 'Cinq séances',
        metric: ChallengeMetric.workouts,
        durationDays: 7,
        invitedUserIds: ['ami-2', 'ami-1'],
        message: 'On y va ?',
      ),
    );

    expect(repository.ids.toSet(), hasLength(1));
    expect(repository.friendChallengeList, hasLength(1));
  });

  test('après un envoi abouti, le même contenu est un NOUVEAU défi', () async {
    await actions().createFriendChallenge(brouillon);
    await actions().createFriendChallenge(brouillon);

    expect(repository.ids.toSet(), hasLength(2));
  });
}

/// Un serveur qui ÉCRIT le défi, puis dont la réponse se perd ; idempotent
/// par identifiant, comme le vrai.
class _ReponsePerdue extends FakeCommunityRepository {
  bool perdreLaReponse = false;
  final List<String> ids = [];

  @override
  Future<FriendChallenge> createFriendChallenge(
    String id,
    NewFriendChallenge challenge,
  ) async {
    ids.add(id);
    final existant = friendChallengeList.where((c) => c.id == id);
    final cree = existant.isNotEmpty
        ? existant.first
        : await super.createFriendChallenge(id, challenge);
    if (perdreLaReponse) {
      throw const NetworkException('réponse perdue (voulu par le test)');
    }
    return cree;
  }
}
