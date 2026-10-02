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
    this.live,
    this.isOffline = false,
    this.isReadOnly = false,
    this.notice,
  });

  final CoachConversation conversation;

  /// Le tour EN COURS : la question partie, et la réponse telle qu'elle
  /// s'écrit. `null` quand rien n'est en route.
  final CoachLiveTurn? live;

  /// Un envoi est parti, la réponse n'est pas revenue.
  bool get isSending => live != null;

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
    CoachLiveTurn? live,
    // Même raison que `clearNotice` : `null` voudrait dire « inchangé ».
    bool clearLive = false,
    bool? isOffline,
    bool? isReadOnly,
    // `notice` se remet à zéro à chaque envoi : un drapeau explicite évite
    // qu'un `null` passé volontairement soit confondu avec « inchangé ».
    bool clearNotice = false,
    String? notice,
  }) {
    return CoachThreadState(
      conversation: conversation ?? this.conversation,
      live: clearLive ? null : (live ?? this.live),
      isOffline: isOffline ?? this.isOffline,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

/// Un tour de conversation pendant qu'il s'écrit.
class CoachLiveTurn {
  const CoachLiveTurn({
    required this.question,
    this.text = '',
    this.ahead,
    this.steps = const [],
    this.stepRunning = false,
  });

  /// La question envoyée, affichée tout de suite sans attendre le serveur.
  final String question;

  /// La réponse reçue jusqu'ici. Vide : le coach réfléchit encore (il lit
  /// tes séances, tes records) avant d'écrire son premier mot.
  final String text;

  /// En file d'attente : demandes qui passent avant celle-ci. `null` : son
  /// tour est venu (ou n'a jamais attendu).
  final int? ahead;

  /// Sa réflexion jusqu'ici : ce qu'il a fait (« Je regarde tes records »),
  /// la dernière étape étant celle en cours.
  final List<String> steps;

  /// La dernière étape se fait encore : rien ne s'est écrit depuis.
  final bool stepRunning;

  CoachLiveTurn append(String more) =>
      CoachLiveTurn(question: question, text: text + more, steps: steps);

  CoachLiveTurn queued(int ahead) =>
      CoachLiveTurn(question: question, text: text, ahead: ahead, steps: steps);

  CoachLiveTurn started() =>
      CoachLiveTurn(question: question, text: text, steps: steps);

  CoachLiveTurn step(String label) =>
      CoachLiveTurn(question: question, text: text, steps: [...steps, label]);
}
