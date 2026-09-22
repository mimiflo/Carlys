/// LES SEPT SOURCES DE L'ÉCRAN COMMUNAUTÉ, et ce qu'on en déduit.
///
/// POURQUOI CE FICHIER EXISTE. L'arbitrage erreur / chargement / vide vivait
/// en ligne dans le `build` de l'écran, sous la forme de trois chaînes de
/// `??` et de `&&`. Il avait été écrit pour CINQ sources ; la ligue et les
/// défis entre amis sont arrivés ensuite, et personne ne les y a ajoutés —
/// leur panne effaçait leur section sous un écran qui se déclarait par
/// ailleurs en bon état. Une liste qu'il faut penser à rallonger à trois
/// endroits finit toujours par diverger.
///
/// Les sept sources sont donc nommées UNE fois, et les trois déductions en
/// découlent. Ajouter une source est désormais une seule ligne, et elle
/// entre dans les trois arbitrages du même geste.
///
/// Dérivé et sans état propre : `providers/`, pas `controllers/`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';

/// Redemande TOUT au serveur, et attend la réponse.
///
/// Les MÊMES sept sources que l'arbitrage ci-dessous, et c'est pourquoi les
/// deux vivent ici : une source ajoutée à l'un sans l'autre est exactement
/// ce qui était arrivé à la ligue et aux défis entre amis.
///
/// L'attente n'est pas décorative : `RefreshIndicator` garde son anneau tant
/// que ce futur n'est pas terminé, et le geste doit durer aussi longtemps
/// que l'appel.
///
/// ELLE NE DOIT PAS JETER. L'anneau se contente d'attendre le futur rendu :
/// personne ne reçoit son erreur, et tirer pour rafraîchir hors ligne levait
/// une exception non traitée. L'échec est déjà DIT par l'écran — chaque
/// source porte son `error`, et l'arbitrage le montre —, donc ici il se
/// journalise et l'anneau se referme normalement.
Future<void> reloadCommunity(WidgetRef ref) async {
  ref
    ..invalidate(encouragementsProvider)
    ..invalidate(communityFriendsProvider)
    ..invalidate(friendRequestsProvider)
    ..invalidate(communityChallengesProvider)
    ..invalidate(friendChallengesProvider)
    ..invalidate(leagueProvider)
    ..invalidate(blockedUsersProvider);
  try {
    await Future.wait([
      ref.read(encouragementsProvider.future),
      ref.read(communityFriendsProvider.future),
      ref.read(friendRequestsProvider.future),
      ref.read(communityChallengesProvider.future),
      ref.read(friendChallengesProvider.future),
      ref.read(leagueProvider.future),
      ref.read(blockedUsersProvider.future),
    ]);
  } on Exception catch (error) {
    AppLogger('community').warning('Communauté non rafraîchie', error: error);
  }
}

/// L'état global de l'écran, déduit de ses sources.
class CommunityScreenState {
  const CommunityScreenState({
    required this.error,
    required this.loaded,
    required this.isEmpty,
  });

  /// La PREMIÈRE erreur, qui porte la cause : hors ligne ou panne, l'état
  /// affiché le dit. Une erreur n'est PAS un écran vide — « personne ici »
  /// serait un mensonge si le serveur a simplement refusé de répondre.
  final Object? error;

  /// Aucune source n'est encore en vol.
  final bool loaded;

  /// Rien à montrer, DE CE QUI SE COMPTE. Toutes les sources participent à
  /// l'erreur et au chargement ; le vide, lui, ne regarde que les listes
  /// dont l'absence veut dire « personne ici ».
  final bool isEmpty;

  /// Vrai quand l'écran peut afficher l'état VIDE : plus rien en vol, aucune
  /// erreur, et rien à montrer.
  bool get showsEmpty => loaded && error == null && isEmpty;
}

/// Déduit l'état de l'écran de ses sources.
///
/// [porteursDuVide] sont les seules sources dont l'absence fait un écran
/// vide ; toutes participent en revanche à l'erreur et au chargement.
CommunityScreenState communityScreenState({
  required List<AsyncValue<Object?>> sources,
  required List<AsyncValue<List<Object?>>> porteursDuVide,
}) {
  Object? premiereErreur;
  var enVol = false;
  for (final source in sources) {
    premiereErreur ??= source.error;
    enVol = enVol || source.isLoading;
  }
  return CommunityScreenState(
    error: premiereErreur,
    loaded: !enVol,
    isEmpty: porteursDuVide.every(
      (source) => source.valueOrNull?.isEmpty ?? true,
    ),
  );
}
