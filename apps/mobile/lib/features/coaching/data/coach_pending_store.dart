/// La question en cours de réponse, gardée sur l'appareil.
///
/// Le serveur finit toute réponse commencée et l'archive, même page quittée
/// ou appli fermée : il faut seulement se souvenir, au retour, de QUELLE
/// question l'attend — son fil, son identifiant (la clé du rejeu), son texte
/// et l'heure d'envoi (le chrono reprend où il en était). Une lecture ratée
/// rend `null` : rien à reprendre, jamais une erreur. Propre au COMPTE : la
/// purge du changement de compte l'efface.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/entities/coach.dart';
import '../domain/services/coach_reply_awaiter.dart';

typedef CoachPendingQuestion = ({
  String conversationId,
  String id,
  String content,
  DateTime since,
});

class CoachPendingStore {
  const CoachPendingStore();

  static const String key = 'coach.question.en.cours';
  static const _logger = AppLogger('CoachPendingStore');

  /// La question gardée, si sa réponse manque à [conversation]. Déjà
  /// répondue (la réplique la suit dans le fil), ou plus vieille que
  /// l'attente permise — le serveur ne l'écrit plus, et la reprendre la
  /// reposerait sans qu'on l'ait redemandée —, elle est oubliée.
  Future<CoachPendingQuestion?> unansweredIn(
    CoachConversation conversation,
  ) async {
    final pending = await read();
    if (pending == null || pending.conversationId != conversation.id) {
      return null;
    }
    final messages = conversation.messages;
    final at = messages.indexWhere((m) => m.id == pending.id);
    final fresh =
        DateTime.now().toUtc().difference(pending.since) < coachReplyPatience;
    if (fresh && (at < 0 || at == messages.length - 1)) return pending;
    await clear();
    return null;
  }

  Future<CoachPendingQuestion?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        conversationId: json['conversationId'] as String,
        id: json['id'] as String,
        content: json['content'] as String,
        since: DateTime.parse(json['since'] as String),
      );
    } on Object catch (error) {
      _logger.warning('Question en cours illisible : ignorée', error: error);
      return null;
    }
  }

  /// Jamais d'erreur : la reprise est un plus, pas une condition de l'envoi.
  Future<void> save(CoachPendingQuestion question) => _write(
    (prefs) => prefs.setString(
      key,
      jsonEncode({
        'conversationId': question.conversationId,
        'id': question.id,
        'content': question.content,
        'since': question.since.toUtc().toIso8601String(),
      }),
    ),
  );

  Future<void> clear() => _write((prefs) => prefs.remove(key));

  Future<void> _write(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } on Object catch (error) {
      _logger.warning('Question en cours non gardée', error: error);
    }
  }
}
