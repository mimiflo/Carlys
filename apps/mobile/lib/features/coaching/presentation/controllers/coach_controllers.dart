/// Providers du coach — **seule porte d'entrée de l'écran**.
///
/// Aucun widget n'appelle l'API : écran → contrôleur → repository.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../subscription/data/repositories/subscription_repository_impl.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coach_thread_state.dart';
import '../../domain/repositories/coach_repository.dart';
import '../utils/coach_notice.dart';

// L'état du fil vit dans le domaine, les amorces dans `providers/` (elles ne
// portent aucun Notifier) ; les deux se relisent par ce fichier, comme avant,
// pour que l'écran et ses tests n'aient pas à changer d'import.
export '../../domain/entities/coach_thread_state.dart';
export '../providers/coach_proposal_actions.dart';
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

  /// Se termine quand la personne arrête la réponse en cours.
  Completer<void>? _cancel;

  /// Le fil affiché est la copie gardée sur l'appareil, lue hors ligne.
  bool _fromCache = false;

  /// La LECTURE de ses conversations reste ouverte à qui les a écrites,
  /// abonné ou non : les CGU promettent que ce qui a été créé avec le Premium
  /// reste consultable. Seules la création d'un fil et l'envoi d'un message
  /// demandent le droit au coach, et c'est le serveur qui le tient.
  @override
  Future<CoachThreadState> build() async {
    final repository = ref.watch(coachRepositoryProvider);
    _fromCache = false;
    try {
      return await _load(repository);
    } on NetworkException {
      // Hors ligne : le dernier fil relu sur cet appareil. Le composeur dit
      // « hors ligne », et « Réessayer » relira le serveur.
      final cached = await repository.offlineConversation();
      if (cached == null) rethrow;
      _created = true;
      _fromCache = true;
      return CoachThreadState(conversation: cached, isOffline: true);
    }
  }

  Future<CoachThreadState> _load(CoachRepository repository) async {
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

    // La question s'affiche aussitôt ; la réponse viendra s'écrire dessous.
    state = AsyncData(
      current.copyWith(
        live: CoachLiveTurn(question: trimmed),
        isOffline: false,
        clearNotice: true,
      ),
    );

    final repository = ref.read(coachRepositoryProvider);
    final cancel = _cancel = Completer<void>();
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
        onText: (text) => _updateLive((live) => live.append(text)),
        onQueued: (ahead) => _updateLive((live) => live.queued(ahead)),
        onStarted: () => _updateLive((live) => live.started()),
        cancel: cancel.future,
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
          // `current` est l'état d'AVANT l'envoi : il porte encore le refus
          // précédent, que l'affichage optimiste venait justement d'effacer.
          // Sans ce drapeau, « Tu as atteint le nombre de messages du jour »
          // réapparaissait sous la réponse qu'on venait de recevoir.
          clearNotice: true,
          clearLive: true,
        ),
      );
      return true;
    } on AppException catch (exception) {
      if (cancel.isCompleted) {
        // Arrêtée par la personne : ni avis ni hors ligne, la question reste
        // dans le champ, et son identifiant pour un renvoi sans doublon.
        state = AsyncData(current.copyWith(clearLive: true));
        return false;
      }
      state = AsyncData(
        current.copyWith(
          clearLive: true,
          isOffline: exception is NetworkException,
          // 403 : le droit au coach est parti. Le fil reste à relire.
          isReadOnly: exception is ForbiddenException,
          notice: exception is ForbiddenException
              ? null
              : coachNoticeFor(exception),
        ),
      );
      return false;
    }
  }

  /// Arrête la réponse en cours : le serveur cesse de générer.
  void stop() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  /// Le tour en cours avance : file, premier mot, morceau de texte.
  void _updateLive(CoachLiveTurn Function(CoachLiveTurn live) update) {
    final now = state.valueOrNull;
    final live = now?.live;
    if (now == null || live == null) return;
    state = AsyncData(now.copyWith(live: update(live)));
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
    // La copie gardée peut dater : réseau revenu, le serveur fait foi.
    if (_fromCache) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData(current.copyWith(isOffline: false, clearNotice: true));
  }
}

final coachThreadProvider =
    AsyncNotifierProvider.autoDispose<CoachThread, CoachThreadState>(
      CoachThread.new,
    );
