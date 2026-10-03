/// Providers du coach — **seule porte d'entrée de l'écran**.
///
/// Aucun widget n'appelle l'API : écran → contrôleur → repository.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../data/coach_pending_store.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../domain/entities/coach_thread_state.dart';
import '../../domain/services/coach_reply_awaiter.dart';
import '../providers/coach_thread_loader.dart';
import '../utils/coach_notice.dart';

// L'état du fil vit dans le domaine, les amorces dans `providers/` (sans
// Notifier) : réexportés ici, l'écran et ses tests gardent leur import.
export '../../domain/entities/coach_thread_state.dart';
export '../providers/coach_greeting_providers.dart';
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

  /// Le tour en cours se termine quand on cesse d'ÉCOUTER sa réponse :
  /// `true` pour « Arrêter » (le serveur cesse aussi), `false` pour la page
  /// quittée ou le fil reconstruit (le serveur finit, la question reste à
  /// reprendre). Propre à CHAQUE tour : l'instance survit aux reconstructions.
  Completer<bool>? _cancel;

  static const _pendingStore = CoachPendingStore();

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
    // Page quittée : on cesse d'écouter, le serveur finit sa réponse.
    ref.onDispose(() {
      final cancel = _cancel;
      if (cancel != null && !cancel.isCompleted) cancel.complete(false);
    });
    try {
      final loaded = await loadCoachThread(ref, repository);
      _created = loaded.created;
      return _resumeIfPending(loaded.state);
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

  /// Une question partie avant qu'on quitte la page, ou ferme l'appli, et
  /// dont la réponse n'est pas dans le fil : le coach l'écrit encore, ou l'a
  /// finie entre-temps. On la remet en cours, et on va la chercher.
  Future<CoachThreadState> _resumeIfPending(CoachThreadState loaded) async {
    final pending = await _pendingStore.unansweredIn(loaded.conversation);
    if (pending == null) return loaded;
    _pending = (id: pending.id, content: pending.content);
    final cancel = _cancel = Completer<bool>();
    unawaited(
      Future.microtask(() => _converse(pending.id, pending.content, cancel)),
    );
    return loaded.copyWith(
      live: CoachLiveTurn(question: pending.content, since: pending.since),
    );
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
    final since = DateTime.now();
    state = AsyncData(
      current.copyWith(
        live: CoachLiveTurn(question: trimmed, since: since),
        isOffline: false,
        clearNotice: true,
      ),
    );
    final pending = _pending;
    final messageId = (pending != null && pending.content == trimmed)
        ? pending.id
        : _uuid.v4();
    _pending = (id: messageId, content: trimmed);
    final cancel = _cancel = Completer<bool>();
    // Gardée sur l'appareil : appli fermée, la réponse se reprend au retour.
    await _pendingStore.save((
      conversationId: current.conversation.id,
      id: messageId,
      content: trimmed,
      since: since,
    ));
    return _converse(messageId, trimmed, cancel);
  }

  /// Le tour : la réponse, attendue même si le serveur l'écrit encore
  /// (renvoi après un retour), jusqu'à ce qu'elle arrive ou qu'on arrête.
  Future<bool> _converse(
    String messageId,
    String content,
    Completer<bool> cancel,
  ) async {
    // Reprise : lancée depuis `build`, avant que son état ne soit posé.
    final current = state.valueOrNull ?? await future;
    final repository = ref.read(coachRepositoryProvider);
    try {
      if (!_created) {
        await repository.createConversation(current.conversation.id);
        _created = true;
      }
      final reply = await awaitCoachReply(
        () => repository.sendMessage(
          conversationId: current.conversation.id,
          messageId: messageId,
          content: content,
          onText: (text) => _updateLive((live) => live.append(text)),
          onQueued: (ahead) => _updateLive((live) => live.queued(ahead)),
          onStarted: () => _updateLive((live) => live.started()),
          onStep: (step) => _updateLive((live) => live.step(step)),
          cancel: cancel.future,
        ),
        stopped: () => cancel.isCompleted,
      );
      _pending = null;
      await _pendingStore.clear();
      // Fil reconstruit entre-temps : c'est SON tour qui affichera la réponse.
      if (cancel.isCompleted) return true;
      state = AsyncData(current.withReply(reply));
      return true;
    } on AppException catch (exception) {
      final stopped = cancel.isCompleted ? await cancel.future : null;
      // Page quittée, fil reconstruit : rien à afficher, la question reste
      // à reprendre.
      if (stopped == false) return false;
      if (stopped == true || exception is! NetworkException) {
        // Arrêtée, ou refusée pour de bon : plus rien à reprendre au retour.
        // (Hors ligne, elle reste : le serveur a peut-être sa réponse.)
        await _pendingStore.clear();
      }
      if (stopped == true) {
        // Arrêtée par la personne : ni avis ni hors ligne, la question reste
        // dans le champ, et son identifiant pour un renvoi sans doublon.
        state = AsyncData(current.copyWith(clearLive: true));
        return false;
      }
      state = AsyncData(
        current.failed(exception, notice: coachNoticeFor(exception)),
      );
      return false;
    }
  }

  /// « Arrêter » : on cesse d'écouter, et le SERVEUR cesse d'écrire.
  void stop() {
    final cancel = _cancel;
    if (cancel == null || cancel.isCompleted) return;
    cancel.complete(true);
    final conversationId = state.valueOrNull?.conversation.id;
    final messageId = _pending?.id;
    if (conversationId == null || messageId == null) return;
    ref
        .read(coachRepositoryProvider)
        .cancelMessage(conversationId: conversationId, messageId: messageId)
        .catchError(
          (Object error) =>
              _logger.warning('Arrêt non transmis au serveur', error: error),
        );
  }

  /// Le tour en cours avance : file, étape, premier mot, morceau de texte.
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
