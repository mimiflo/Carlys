import 'package:carlys_mobile/features/community/domain/entities/friend_challenge.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/friend_challenge/friend_challenge_wording.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QU'UN DÉFI ENTRE AMIS PROMET, cas par cas. La maquette promettait des
/// points et une validation collective : ni l'un ni l'autre n'existe.
void main() {
  FriendChallengeMember membre(
    String name, {
    FriendChallengeMemberStatus status = FriendChallengeMemberStatus.accepted,
    bool isMe = false,
    bool isCreator = false,
    int? rank,
  }) => FriendChallengeMember(
    userId: 'u-$name',
    displayName: name,
    status: status,
    contribution: 0,
    rank: rank,
    isMe: isMe,
    isCreator: isCreator,
  );

  FriendChallenge defi({
    ChallengeMetric metric = ChallengeMetric.workouts,
    int? target = 5,
    FriendChallengeStatus status = FriendChallengeStatus.open,
    FriendChallengeMemberStatus myStatus = FriendChallengeMemberStatus.invited,
    List<FriendChallengeMember>? members,
    int? durationDays = 7,
    Duration reste = const Duration(days: 6, hours: 3),
  }) {
    final now = DateTime.now();
    return FriendChallenge(
      id: 'defi',
      title: 'Cinq séances cette semaine',
      metric: metric,
      unit: 'séances',
      target: target,
      status: status,
      myStatus: myStatus,
      startsAt: now.subtract(const Duration(days: 1)),
      endsAt: now.add(reste),
      creatorDisplayName: 'Léa',
      durationDays: durationDays,
      members:
          members ??
          [
            membre('Léa', isCreator: true, rank: 1),
            membre(
              'Camille',
              isMe: true,
              status: FriendChallengeMemberStatus.invited,
            ),
          ],
    );
  }

  group('le compte à rebours', () {
    test('J−N, puis le dernier jour, puis terminé', () {
      expect(friendChallengeCountdown(defi()), 'J−6');
      expect(
        friendChallengeCountdown(defi(reste: const Duration(hours: 4))),
        'Dernier jour',
      );
      expect(
        friendChallengeCountdown(defi(status: FriendChallengeStatus.closed)),
        'Terminé',
      );
    });
  });

  group('qui défie qui', () {
    test('invité : « Léa te défie »', () {
      expect(friendChallengeOrigin(defi()), 'Léa te défie');
    });

    test('dedans : « Lancé par Léa »', () {
      expect(
        friendChallengeOrigin(
          defi(myStatus: FriendChallengeMemberStatus.accepted),
        ),
        'Lancé par Léa',
      );
    });

    test('lancé par moi : « Tu as lancé ce défi »', () {
      expect(
        friendChallengeOrigin(
          defi(
            myStatus: FriendChallengeMemberStatus.accepted,
            members: [membre('Camille', isMe: true, isCreator: true, rank: 1)],
          ),
        ),
        'Tu as lancé ce défi',
      );
    });
  });

  group('les quantités, lisibles', () {
    test('séances et bonnes réponses accordées', () {
      expect(friendChallengeAmount(ChallengeMetric.workouts, 1), '1 séance');
      expect(friendChallengeAmount(ChallengeMetric.workouts, 5), '5 séances');
      expect(
        friendChallengeAmount(ChallengeMetric.quizCorrect, 3),
        '3 bonnes réponses',
      );
    });

    test('des minutes plutôt que des secondes', () {
      expect(
        friendChallengeAmount(ChallengeMetric.activeSeconds, 2700),
        '45 min',
      );
      expect(
        friendChallengeAmount(ChallengeMetric.activeSeconds, 3900),
        '1 h 05',
      );
    });

    test('des kilomètres au-delà du kilomètre', () {
      expect(
        friendChallengeAmount(ChallengeMetric.distanceMeters, 800),
        '800 m',
      );
      expect(
        friendChallengeAmount(ChallengeMetric.distanceMeters, 12400),
        '12,4 km',
      );
    });
  });

  group('les faits de l’en-tête', () {
    test('l’objectif commun, ou « le plus » sans objectif', () {
      expect(friendChallengeGoal(defi()), (value: '5', label: 'séances'));
      expect(friendChallengeGoal(defi(target: null)), (
        value: 'Le plus',
        label: 'de séances',
      ));
    });

    test('la durée, déduite des bornes pour un serveur plus ancien', () {
      expect(friendChallengeDuration(defi()), (value: '7', label: 'jours'));
      final ancien = FriendChallenge(
        id: 'ancien',
        title: 'Trois jours',
        metric: ChallengeMetric.workouts,
        unit: 'séances',
        status: FriendChallengeStatus.open,
        myStatus: FriendChallengeMemberStatus.accepted,
        startsAt: DateTime.utc(2026, 9, 20),
        endsAt: DateTime.utc(2026, 9, 23),
        creatorDisplayName: 'Léa',
        members: const [],
      );
      expect(friendChallengeDuration(ancien), (value: '3', label: 'jours'));
    });
  });

  group('la règle du jeu', () {
    test('ni point ni titre, et l’objectif s’il existe', () {
      final regles = friendChallengeRules(defi());

      expect(regles.first, contains('Chaque séance terminée compte'));
      expect(
        regles,
        contains('Aucun point ni titre en jeu : juste toi et tes amis.'),
      );
      expect(regles.join(' '), contains('Objectif commun : 5 séances'));
      expect(regles.join(' '), isNot(contains('validé')));
    });

    test('sans objectif, celui qui en fait le plus mène', () {
      expect(
        friendChallengeRules(defi(target: null)),
        contains('Pas d’objectif fixé : celui qui en fait le plus mène.'),
      );
    });
  });

  group('les statuts, sans genrer personne', () {
    test('à l’origine, dans le défi, en attente', () {
      expect(
        friendChallengeMemberStatus(membre('Léa', isCreator: true)),
        'À l’origine',
      );
      expect(friendChallengeMemberStatus(membre('Mehdi')), 'Dans le défi');
      expect(
        friendChallengeMemberStatus(
          membre('Tom', status: FriendChallengeMemberStatus.invited),
        ),
        'En attente',
      );
    });
  });

  test('l’heure du message, en heure locale', () {
    final now = DateTime(2026, 9, 23, 12);
    expect(
      friendChallengeMessageTime(DateTime(2026, 9, 23, 8, 24), now: now),
      'Aujourd’hui, 08h24',
    );
    expect(
      friendChallengeMessageTime(DateTime(2026, 9, 22, 21, 5), now: now),
      'Hier, 21h05',
    );
  });
}
