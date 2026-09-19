import 'coach.dart';

/// État du fil affiché : la conversation, plus ce que l'écran doit savoir
/// pour ne pas mentir à l'utilisateur.
class CoachThreadState {
  const CoachThreadState({
    required this.conversation,
    this.isSending = false,
    this.isOffline = false,
    this.notice,
    this.remainingToday,
  });

  final CoachConversation conversation;

  /// Un envoi est parti, la réponse n'est pas revenue.
  final bool isSending;

  /// Le dernier envoi n'a pas atteint le serveur : le composeur se remplace
  /// par son état hors ligne plutôt que d'accepter une question qui partirait
  /// dans le vide.
  final bool isOffline;

  /// Message court affiché au-dessus du composeur (plafond atteint, coach
  /// momentanément coupé…). Toujours issu d'un refus RÉEL du serveur.
  final String? notice;

  /// Messages restants pour la journée — compté par le serveur, jamais ici.
  final int? remainingToday;

  CoachThreadState copyWith({
    CoachConversation? conversation,
    bool? isSending,
    bool? isOffline,
    int? remainingToday,
    // `notice` se remet à zéro à chaque envoi : un drapeau explicite évite
    // qu'un `null` passé volontairement soit confondu avec « inchangé ».
    bool clearNotice = false,
    String? notice,
  }) {
    return CoachThreadState(
      conversation: conversation ?? this.conversation,
      isSending: isSending ?? this.isSending,
      isOffline: isOffline ?? this.isOffline,
      notice: clearNotice ? null : (notice ?? this.notice),
      remainingToday: remainingToday ?? this.remainingToday,
    );
  }
}
