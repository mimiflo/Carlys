/// Providers du coach — **seule porte d'entrée de l'écran**.
///
/// Aucun widget n'appelle l'API : écran → contrôleur → repository.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../subscription/data/repositories/subscription_repository_impl.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../data/repositories/coach_session_launcher.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coach_thread_state.dart';

// L'état du fil vit dans le domaine, les amorces dans `providers/` (elles ne
// portent aucun Notifier) ; les deux se relisent par ce fichier, comme avant,
// pour que l'écran et ses tests n'aient pas à changer d'import.
export '../../domain/entities/coach_thread_state.dart';
export '../providers/coach_suggestion_providers.dart';

/// Le fil de discussion courant.
///
/// **Le fil n'est créé qu'au premier message.** Ouvrir l'onglet pour regarder
/// ne doit pas laisser derrière soi une conversation vide : l'identifiant est
/// généré sur l'appareil, gardé en local, et le fil naît côté serveur au
/// moment où il a quelque chose à contenir.
class CoachThread extends AutoDisposeAsyncNotifier<CoachThreadState> {
  static const Uuid _uuid = Uuid();
  static const _logger = AppLogger('CoachThread');

  /// Le fil existe côté serveur (créé, ou rapatrié depuis la liste).
  bool _created = false;

  /// Le message EN COURS de tentative : son identifiant et son texte.
  ///
  /// L'identifiant est la clé d'idempotence du serveur, et il était tiré à
  /// NEUF à chaque appui. Une réponse perdue en route (coupure juste après
  /// l'envoi) faisait donc réessayer avec un autre identifiant : le serveur
  /// voyait un second message, le comptait dans le quota du jour et le
  /// facturait, alors que la personne n'avait posé qu'une question. On garde
  /// donc l'identifiant tant que la MÊME question n'est pas passée ; changer
  /// le texte en tire un nouveau, sans quoi le serveur rendrait la réponse de
  /// la question précédente.
  ({String id, String content})? _pending;

  /// La LECTURE de ses conversations reste ouverte à qui les a écrites,
  /// abonné ou non : les CGU promettent que ce qui a été créé avec le Premium
  /// reste consultable. Seules la création d'un fil et l'envoi d'un message
  /// demandent le droit au coach, et c'est le serveur qui le tient.
  @override
  Future<CoachThreadState> build() async {
    final repository = ref.watch(coachRepositoryProvider);
    final threads = await repository.conversations();
    final mayWrite = await _mayWrite();

    if (threads.isEmpty) {
      // Rien à relire, et rien à écrire : l'invitation à l'abonnement, plutôt
      // qu'un fil vide qui refuserait la première question.
      if (!mayWrite) throw const ForbiddenException(_reserved, statusCode: 403);
      _created = false;
      return CoachThreadState(
        conversation: CoachConversation(id: _uuid.v4(), messages: const []),
      );
    }

    _created = true;
    return CoachThreadState(
      conversation: await repository.conversation(threads.first.id),
      isReadOnly: !mayWrite,
    );
  }

  static const _reserved = 'Le coach est réservé aux abonnés.';

  /// Le droit au coach, tel que le SERVEUR l'a décidé (`GET /entitlements`).
  /// Inconnu (hors ligne, panne) : on laisse écrire, et l'envoi rapportera
  /// le vrai refus, s'il y en a un.
  Future<bool> _mayWrite() async {
    try {
      final droits = await ref
          .read(subscriptionRepositoryProvider)
          .entitlements();
      return droits.any((d) => d.key == 'ai_coaching' && d.isActive);
    } on Object catch (error) {
      _logger.warning(
        'Droit au coach inconnu : écriture permise',
        error: error,
      );
      return true;
    }
  }

  /// Envoie une question et attend la réplique.
  ///
  /// Rend `true` quand le message est parti — l'écran vide alors son champ de
  /// saisie. Sur échec, le texte reste : rien n'est perdu.
  Future<bool> send(String content) async {
    final trimmed = content.trim();
    final current = state.valueOrNull;
    if (trimmed.isEmpty || current == null || current.isSending) return false;

    state = AsyncData(
      current.copyWith(isSending: true, isOffline: false, clearNotice: true),
    );

    final repository = ref.read(coachRepositoryProvider);
    try {
      if (!_created) {
        await repository.createConversation(current.conversation.id);
        _created = true;
      }

      final pending = _pending;
      final messageId = (pending != null && pending.content == trimmed)
          ? pending.id
          : _uuid.v4();
      _pending = (id: messageId, content: trimmed);

      final reply = await repository.sendMessage(
        conversationId: current.conversation.id,
        messageId: messageId,
        content: trimmed,
      );

      _pending = null;
      state = AsyncData(
        current.copyWith(
          conversation: CoachConversation(
            id: current.conversation.id,
            title: current.conversation.title,
            messages: [
              ...current.conversation.messages,
              reply.userMessage,
              reply.assistantMessage,
            ],
          ),
          isSending: false,
          // `current` est l'état d'AVANT l'envoi : il porte encore le refus
          // précédent, que l'affichage optimiste venait justement d'effacer.
          // Sans ce drapeau, « Tu as atteint le nombre de messages du jour »
          // réapparaissait sous la réponse qu'on venait de recevoir.
          clearNotice: true,
        ),
      );
      return true;
    } on AppException catch (exception) {
      state = AsyncData(
        current.copyWith(
          isSending: false,
          isOffline: exception is NetworkException,
          // 403 : le droit au coach est parti. Le fil reste à relire.
          isReadOnly: exception is ForbiddenException,
          notice: exception is ForbiddenException
              ? null
              : _noticeFor(exception),
        ),
      );
      return false;
    }
  }

  /// Rouvre le composeur après une coupure.
  ///
  /// POURQUOI CETTE MÉTHODE EXISTE. Le drapeau hors ligne ne se levait que
  /// dans `send()` — or hors ligne, le composeur ET les suggestions sont
  /// masqués, donc `send()` était devenu inatteignable : le coach restait
  /// muet jusqu'à ce qu'on quitte l'écran et qu'on le rouvre, réseau revenu
  /// ou pas. Une fonctionnalité payante condamnée par deux secondes de
  /// métro.
  void clearOffline() {
    final current = state.valueOrNull;
    if (current == null || !current.isOffline) {
      return;
    }
    state = AsyncData(current.copyWith(isOffline: false, clearNotice: true));
  }

  /// Texte utilisateur d'un refus du serveur. Hors ligne, le composeur dit
  /// déjà ce qu'il faut : pas de second message redondant.
  String? _noticeFor(AppException exception) {
    if (exception is NetworkException) return null;
    if (exception is ServerException) {
      return switch (exception.statusCode) {
        429 =>
          'Tu as atteint le nombre de messages du jour. '
              'Le coach revient demain.',
        503 => 'Le coach est momentanément indisponible.',
        _ => 'Le coach n’a pas pu répondre. Réessaie dans un instant.',
      };
    }
    return 'Le coach n’a pas pu répondre. Réessaie dans un instant.';
  }
}

final coachThreadProvider =
    AsyncNotifierProvider.autoDispose<CoachThread, CoachThreadState>(
      CoachThread.new,
    );

/// Lance la séance proposée et signale l'acceptation au serveur.
///
/// L'ordre compte : la séance est écrite en local **d'abord**. Si la note au
/// serveur échoue, l'utilisateur s'entraîne quand même — c'est une statistique
/// qui manque, pas une séance perdue.
class CoachProposalActions {
  const CoachProposalActions(this._ref);

  final Ref _ref;

  Future<String> start(CoachSessionProposal proposal) async {
    // Une proposition DÉJÀ acceptée a déjà sa séance : le serveur nous dit
    // laquelle (`acceptedSessionId`), et l'appui suivant doit y ramener, pas
    // en créer une seconde. Sans ce garde-fou, rouvrir le fil et réappuyer
    // fabriquait une séance de plus à chaque fois — sitôt la précédente
    // terminée, puisque la règle « au plus une séance en cours » ne bloque
    // que pendant. L'historique se remplissait de séances jamais faites.
    final already = proposal.acceptedSessionId;
    if (already != null) {
      return already;
    }

    final sessionId = await _ref
        .read(coachSessionLauncherProvider)
        .start(proposal);

    try {
      await _ref
          .read(coachRepositoryProvider)
          .markProposalAccepted(proposalId: proposal.id, sessionId: sessionId);
    } on AppException {
      // Volontairement avalé : la séance existe, elle est en file de
      // synchronisation, et l'écran de séance s'ouvre. Rien à dire ici.
    }

    return sessionId;
  }
}

final coachProposalActionsProvider = Provider<CoachProposalActions>(
  CoachProposalActions.new,
);
