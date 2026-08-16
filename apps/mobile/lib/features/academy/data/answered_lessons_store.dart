/// Les questions de l'Academy auxquelles l'utilisateur a RÉPONDU, gardées sur
/// l'appareil, avec le choix qu'il a fait.
///
/// ## Pourquoi une copie locale
///
/// Les réponses partent déjà au serveur, pour les défis culturels. Mais cet
/// envoi est en ÉCRITURE SEULE : aucun endpoint ne permet de les relire.
/// Deux besoins en dépendent pourtant, et tous deux doivent tenir hors ligne :
/// l'axe « Maîtrise » du profil de progression, et l'état des cartes de quiz.
///
/// Cette copie n'est donc pas une duplication de confort : c'est la seule
/// source lisible qui existe. Le jour où l'API exposera la lecture, ce dépôt
/// deviendra un cache et se remplacera sans toucher au moteur de calcul, qui
/// ne connaît qu'un nombre.
///
/// ## Pourquoi on garde le CHOIX, et pas seulement « répondu »
///
/// La même question apparaît à deux endroits : la « question du jour » de
/// l'accueil, et la leçon dans sa catégorie de l'Academy. Y répondre une fois
/// doit se voir aux deux endroits — sinon la question semble revenir, et
/// répondre deux fois n'a aucun sens.
///
/// Pour cela, ne retenir que « répondu » ne suffirait pas : la carte
/// afficherait la bonne réponse sans montrer celle qui a été donnée, donc
/// elle laisserait croire à une bonne réponse même quand on s'est trompé.
/// Réécrire l'histoire du côté flatteur serait un mensonge, et Carlys ne
/// ment pas à l'utilisateur.
///
/// Ce choix conservé ne sert QU'À L'AFFICHAGE. Le score, lui, compte les
/// questions abordées et jamais les bonnes réponses : se tromper fait
/// apprendre, et noter les échecs transformerait l'Academy en examen.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';

/// Persistance locale des questions abordées.
class AnsweredLessonsStore {
  const AnsweredLessonsStore();

  static const _logger = AppLogger('AnsweredLessonsStore');

  /// Clé des préférences locales.
  static const String key = 'academy.lecons_repondues';

  /// Identifiant de leçon vers l'index du choix retenu.
  Future<Map<String, int>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const {};
      }
      return {
        for (final entry in decoded.entries)
          if (entry.value is int) entry.key: entry.value as int,
      };
    } on FormatException catch (error) {
      // Préférences abîmées : on repart d'une ardoise vierge plutôt que de
      // faire échouer l'Academy. Le pire est de reposer une question.
      _logger.warning('Réponses locales illisibles', error: error);
      return const {};
    }
  }

  /// Note une réponse. IDEMPOTENT, et la PREMIÈRE gagne : rouvrir une leçon
  /// ne réécrit pas ce qui a été répondu, et un score dérivé ne peut pas
  /// compter deux fois la même question.
  Future<void> markAnswered(String lessonId, int choiceIndex) async {
    final current = Map<String, int>.from(await read());
    if (current.containsKey(lessonId)) {
      return;
    }
    current[lessonId] = choiceIndex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(current));
  }
}

final answeredLessonsStoreProvider = Provider<AnsweredLessonsStore>(
  (ref) => const AnsweredLessonsStore(),
);
