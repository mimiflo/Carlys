import '../entities/coach.dart';
import '../entities/coach_thread_state.dart';

/// Contrat du domaine coach.
///
/// **Seul domaine de l'application qui n'écrit pas hors ligne**, et c'est
/// délibéré : une question posée sans réseau recevrait sa réponse des heures
/// plus tard, ce qui n'est plus une conversation. Les identifiants, eux,
/// restent générés sur l'appareil — ouvrir un fil et envoyer un message sont
/// donc rejouables sans créer de doublon.
abstract interface class CoachRepository {
  /// Fils de l'utilisateur, du plus récemment actif au plus ancien.
  Future<List<CoachConversationSummary>> conversations();

  /// Ouvre un fil sur un identifiant fourni par l'appareil (rejouable).
  Future<CoachConversationSummary> createConversation(String id);

  /// Un fil avec ses messages et les séances proposées.
  Future<CoachConversation> conversation(String id);

  /// Le dernier fil relu SUR CET APPAREIL, échanges suivants compris, pour
  /// le relire hors ligne ; `null` si rien n'est gardé. Relire n'attend pas
  /// le réseau — écrire, si.
  Future<CoachConversation?> offlineConversation();

  /// Envoie un message et rend la réplique du coach, telle qu'archivée.
  ///
  /// [onText] reçoit la réponse AU FIL de son écriture, morceau par morceau :
  /// de quoi l'afficher en direct. La réplique rendue à la fin fait foi.
  ///
  /// [messageId] vient de l'appareil : renvoyer la même requête ne crée aucun
  /// doublon.
  ///
  /// Le coach très sollicité fait attendre : [onQueued] reçoit le nombre de
  /// demandes qui passent avant, [onStarted] dit que c'est son tour. [onStep]
  /// reçoit chaque étape de sa réflexion (« Je regarde tes records »), quand
  /// elle commence puis quand elle finit (`done`). Quand
  /// [cancel] se termine (« Arrêter »), la requête est abandonnée et le
  /// serveur arrête de générer ; l'envoi échoue alors.
  Future<CoachReply> sendMessage({
    required String conversationId,
    required String messageId,
    required String content,
    void Function(String text)? onText,
    void Function(int ahead)? onQueued,
    void Function()? onStarted,
    void Function(CoachStep step)? onStep,
    Future<void>? cancel,
  });

  /// Signale qu'une proposition a été lancée. N'écrit **aucune** séance : la
  /// séance naît par le chemin de séance existant, déjà idempotent.
  Future<void> markProposalAccepted({
    required String proposalId,
    required String sessionId,
  });

  /// Signale qu'un programme proposé a été engendré. N'écrit **aucun**
  /// programme : il naît par la génération existante.
  Future<void> markProgramProposalAccepted({
    required String proposalId,
    required String programId,
  });
}
