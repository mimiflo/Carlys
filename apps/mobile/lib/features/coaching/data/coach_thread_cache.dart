/// Le dernier fil du coach, gardé sur l'appareil pour être RELU hors ligne.
///
/// Le coach reste le seul domaine qui n'ÉCRIT pas hors ligne (voir
/// `CoachRepository`) ; relire, en revanche, n'a aucune raison d'attendre le
/// réseau : ouvrir l'onglet dans le métro montrait l'état hors ligne au lieu
/// de la conversation d'hier.
///
/// On garde le JSON tel que l'API l'a rendu (`GET /coach/conversations/:id`),
/// complété de chaque échange terminé : sa relecture passe par le même
/// `coachConversationFromJson` que la réponse du serveur, sans second format
/// à maintenir.
///
/// Ces messages parlent de poids, de repas, de douleurs : la clé appartient
/// au COMPTE et part avec lui (`LocalAccountPurge.accountOwnedPreferenceKeys`).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/local_account_owner.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/entities/coach.dart';
import 'dto/coach_dtos.dart';

class CoachThreadCache {
  const CoachThreadCache([this._owner = const LocalAccountOwner()]);

  final LocalAccountOwner _owner;

  /// Les derniers messages seulement : la copie se relit et se réécrit en
  /// bloc, et un fil de plusieurs mois n'a pas à peser sur chaque échange.
  static const int maxMessages = 60;

  static const _logger = AppLogger('CoachThreadCache');

  /// Clé des préférences locales.
  static const String key = 'coach.dernier_fil';

  /// Le fil gardé, ou `null` : rien de gardé, ou une copie illisible — le
  /// pire est alors l'état hors ligne d'avant, jamais un plantage.
  Future<CoachConversation?> read() async {
    try {
      final raw = await _readRaw();
      return raw == null ? null : coachConversationFromJson(raw);
    } on Object catch (error) {
      _logger.warning('Fil du coach gardé illisible', error: error.runtimeType);
      return null;
    }
  }

  /// Remplace la copie par le fil que le serveur vient de rendre.
  Future<void> save(Map<String, dynamic> conversation) =>
      _guard(() => _write(conversation));

  /// Ajoute un échange terminé. Un AUTRE fil que celui gardé (le premier
  /// message d'un fil neuf) repart de zéro : on ne garde que le dernier. Un
  /// message déjà gardé ne l'est pas deux fois.
  Future<void> append(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) => _guard(() async {
    final raw = await _readRaw();
    final same = raw != null && raw['id'] == conversationId;
    final kept = same ? _messagesOf(raw) : <Object?>[];
    final ids = {for (final m in kept) (m as Map<String, dynamic>)['id']};
    await _write({
      'id': conversationId,
      'title': same ? raw['title'] : null,
      'messages': [...kept, ...messages.where((m) => !ids.contains(m['id']))],
    });
  });

  /// Note qu'une proposition gardée a été lancée. SANS quoi, hors ligne, la
  /// copie la montrerait encore à lancer, et l'appui suivant fabriquerait
  /// une seconde séance (`CoachProposalActions.start`).
  Future<void> markAccepted(String proposalId, String sessionId) => _guard(
    () async {
      final raw = await _readRaw();
      if (raw == null) return;
      for (final message in _messagesOf(raw)) {
        final proposal = (message as Map<String, dynamic>)['proposal'];
        if (proposal is Map<String, dynamic> && proposal['id'] == proposalId) {
          proposal['acceptedSessionId'] = sessionId;
          await _write(raw);
          return;
        }
      }
    },
  );

  List<Object?> _messagesOf(Map<String, dynamic> raw) =>
      raw['messages'] as List<dynamic>;

  /// La copie ne vaut que pour le compte qui l'a écrite ; elle est illisible
  /// autrement, et abîmée, elle vaut « rien de gardé ».
  Future<Map<String, dynamic>?> _readRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    if (text == null || text.isEmpty) return null;
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> ||
        decoded['id'] is! String ||
        decoded['messages'] is! List<dynamic> ||
        decoded['owner'] != await _owner.read()) {
      return null;
    }
    return decoded;
  }

  /// Sans propriétaire, rien ne s'écrit : c'est l'appareil que la purge vient
  /// de vider. Une réponse en flux qui finit APRÈS la déconnexion ne ressuscite
  /// donc pas l'échange pour le compte suivant — que la purge, marqueur
  /// effacé, n'aurait plus aucune raison d'effacer.
  Future<void> _write(Map<String, dynamic> conversation) async {
    final owner = await _owner.read();
    if (owner == null) return;
    final messages = _messagesOf(conversation);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        ...conversation,
        'owner': owner,
        'messages': messages.length > maxMessages
            ? messages.sublist(messages.length - maxMessages)
            : messages,
      }),
    );
  }

  /// Une copie ratée ne fait jamais échouer la conversation EN LIGNE : elle
  /// se journalise, et le fil se relira du serveur la prochaine fois.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      _logger.warning('Fil du coach non gardé', error: error.runtimeType);
    }
  }
}

final coachThreadCacheProvider = Provider<CoachThreadCache>(
  (ref) => const CoachThreadCache(),
);
