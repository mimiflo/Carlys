/// Ce qui protège dans la communauté : blocages et signalements.
///
/// Tout est décidé CÔTÉ SERVEUR (qui est bloqué, ce qui est dupliqué, qui
/// lit un signalement) ; ces entités ne portent que ce que l'écran doit
/// montrer ou envoyer.
library;

/// Personne que J'AI bloquée.
///
/// Le blocage est unilatéral et OPAQUE : l'autre n'en est jamais informé, il
/// ne voit qu'un compte qui n'existe plus. Bloquer retire l'amitié et les
/// demandes en attente dans les deux sens ; débloquer ne les rétablit pas.
class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
  });

  final String userId;
  final String displayName;
  final DateTime blockedAt;
}

/// Motif d'un signalement : les valeurs de l'enum SERVEUR, libellées en
/// français pour la feuille. Le serveur ne connaît que [serverValue].
enum CommunityReportReason {
  harassment('HARCELEMENT', 'Harcèlement'),
  spam('SPAM', 'Spam ou publicité'),
  inappropriateContent('CONTENU_INAPPROPRIE', 'Contenu inapproprié'),
  other('AUTRE', 'Autre');

  const CommunityReportReason(this.serverValue, this.label);

  /// La valeur telle que l'API la valide (`communityReportReasonSchema`).
  final String serverValue;

  /// Le libellé montré dans la feuille de signalement.
  final String label;
}

/// Longueur maximale des précisions d'un signalement, la borne partagée
/// avec l'API (`COMMUNITY_REPORT_DETAILS_MAX_LENGTH`).
const int communityReportDetailsMaxLength = 500;

/// Un signalement prêt à partir : le motif, et des précisions facultatives
/// déjà nettoyées (blanc = absent, comme le serveur les enregistre).
class CommunityReportDraft {
  CommunityReportDraft({required this.reason, String? details})
    : details = _clean(details);

  final CommunityReportReason reason;
  final String? details;

  static String? _clean(String? raw) {
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
