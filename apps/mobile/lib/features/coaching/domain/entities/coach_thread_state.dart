import 'coach.dart';

/// État du fil affiché : la conversation, plus ce que l'écran doit savoir
/// pour ne pas mentir à l'utilisateur.
///
/// Le compteur de messages restants n'est PAS ici. Le serveur le rend à
/// chaque réponse (`CoachReply.remainingToday`) et l'état le recopiait, mais
/// aucun widget ne le lisait : un champ porté d'un bout à l'autre pour
/// n'être jamais affiché. Le jour où l'écran voudra l'annoncer, il vient de
/// la réponse, pas d'un état qui le traîne en attendant.
class CoachThreadState {
  const CoachThreadState({
    required this.conversation,
    this.isSending = false,
    this.isOffline = false,
    this.isReadOnly = false,
    this.notice,
  });

  final CoachConversation conversation;

  /// Un envoi est parti, la réponse n'est pas revenue.
  final bool isSending;

  /// Le dernier envoi n'a pas atteint le serveur : le composeur se remplace
  /// par son état hors ligne plutôt que d'accepter une question qui partirait
  /// dans le vide.
  final bool isOffline;

  /// Le fil se RELIT, il ne s'écrit plus : le coach est réservé aux abonnés
  /// (le serveur le dit), et l'historique reste à qui l'a écrit. Le composeur
  /// cède la place à une invitation vers l'abonnement.
  final bool isReadOnly;

  /// Message court affiché au-dessus du composeur (plafond atteint, coach
  /// momentanément coupé…). Toujours issu d'un refus RÉEL du serveur.
  final String? notice;

  CoachThreadState copyWith({
    CoachConversation? conversation,
    bool? isSending,
    bool? isOffline,
    bool? isReadOnly,
    // `notice` se remet à zéro à chaque envoi : un drapeau explicite évite
    // qu'un `null` passé volontairement soit confondu avec « inchangé ».
    bool clearNotice = false,
    String? notice,
  }) {
    return CoachThreadState(
      conversation: conversation ?? this.conversation,
      isSending: isSending ?? this.isSending,
      isOffline: isOffline ?? this.isOffline,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
