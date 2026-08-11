import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/domain/repositories/community_repository.dart';

/// Dépôt communauté pilotable : listes en mémoire, pannes à la demande.
class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({
    this.failReads = false,
    List<Encouragement>? feed,
    List<CommunityFriend>? friends,
    List<CommunityChallenge>? challenges,
  })  : _feed = feed ?? [],
        _friends = friends ?? [],
        _challenges = challenges ?? [];

  /// À activer pour simuler un serveur injoignable.
  bool failReads;

  final List<Encouragement> _feed;
  final List<CommunityFriend> _friends;
  final List<CommunityChallenge> _challenges;

  void _guard() {
    if (failReads) {
      throw StateError('communauté injoignable (voulu par le test)');
    }
  }

  @override
  Future<List<Encouragement>> encouragements() async {
    _guard();
    return List.unmodifiable(_feed);
  }

  @override
  Future<List<CommunityFriend>> friends() async {
    _guard();
    return List.unmodifiable(_friends);
  }

  @override
  Future<List<CommunityChallenge>> challenges() async {
    _guard();
    return List.unmodifiable(_challenges);
  }

  @override
  Future<CommunityChallenge> toggleChallenge(String challengeId) async {
    _guard();
    final index = _challenges.indexWhere((c) => c.id == challengeId);
    if (index < 0) {
      throw ArgumentError.value(challengeId, 'challengeId', 'défi inconnu');
    }
    final challenge = _challenges[index];
    final updated = challenge.copyWith(
      joined: !challenge.joined,
      participants: challenge.participants + (challenge.joined ? -1 : 1),
    );
    _challenges[index] = updated;
    return updated;
  }

  @override
  Future<void> encourage(String friendId, String message) async {
    _guard();
  }
}
