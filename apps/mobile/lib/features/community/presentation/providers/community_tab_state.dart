/// L'ONGLET OUVERT de la Communauté, et la recherche en cours.
///
/// La page empilait tout — demandes, fil, amis, défis, ligue,
/// confidentialité — sur un seul défilement. La refonte de septembre 2026 la
/// range en trois onglets ; rien n'a été retiré en chemin.
///
/// Dérivé de gestes, sans source serveur : `providers/`, pas `controllers/`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les trois onglets, dans l'ordre de la piste.
enum CommunityTab {
  defis('defis', 'Défis'),
  ligue('ligue', 'Ligue'),
  amis('amis', 'Amis');

  const CommunityTab(this.slug, this.label);

  /// Ce que la route porte (`/community?onglet=amis`) : un raccourci de
  /// l'accueil ouvre ainsi l'onglet qui répond à ce qu'il annonce.
  final String slug;
  final String label;

  /// L'onglet d'un paramètre de route, ou `null` s'il n'en désigne aucun.
  static CommunityTab? fromSlug(String? slug) {
    for (final tab in CommunityTab.values) {
      if (tab.slug == slug) {
        return tab;
      }
    }
    return null;
  }
}

/// L'onglet ouvert. PAS auto-disposé : l'onglet Communauté vit dans un
/// `IndexedStack`, et revenir sur la page doit rouvrir l'onglet quitté.
final communityTabProvider = StateProvider<CommunityTab>(
  (ref) => CommunityTab.defis,
);

/// La recherche de la Communauté : `null` tant que la loupe est fermée,
/// sinon ce qui est tapé (vide juste après l'ouverture).
///
/// Elle FILTRE ce qui est déjà chargé — tes amis, les noms du classement,
/// les défis — et n'interroge jamais le serveur : il n'énumère personne,
/// par principe (`docs/product/community.md`, principes 2 et 3).
final communitySearchProvider = StateProvider<String?>((ref) => null);
