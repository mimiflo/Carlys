/// Les leçons de l'Academy auxquelles l'utilisateur a RÉPONDU, gardées sur
/// l'appareil.
///
/// ## Pourquoi une copie locale
///
/// Les réponses partent déjà au serveur, pour les défis culturels. Mais cet
/// envoi est en ÉCRITURE SEULE : aucun endpoint ne permet de les relire.
/// L'axe « Maîtrise » du profil de progression a pourtant besoin de savoir
/// combien de leçons ont été abordées, et il doit le savoir hors ligne, comme
/// tout le reste du profil.
///
/// Cette copie n'est donc pas une duplication de confort : c'est la seule
/// source lisible qui existe. Le jour où l'API exposera la lecture, ce dépôt
/// deviendra un cache et se remplacera sans toucher au moteur de calcul, qui
/// ne connaît qu'un nombre.
///
/// ## Ce qu'on garde, et ce qu'on ne garde pas
///
/// On garde l'identifiant des leçons abordées, et rien d'autre : ni la
/// réponse donnée, ni l'heure, ni le nombre d'essais. Se tromper fait
/// apprendre — conserver les échecs pour les compter serait un fichier de
/// mauvaises notes, exactement ce que la marque refuse.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistance locale des leçons abordées.
class AnsweredLessonsStore {
  const AnsweredLessonsStore();

  /// Clé des préférences locales.
  static const String key = 'academy.lecons_repondues';

  /// Identifiants des leçons déjà abordées.
  Future<Set<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const <String>[]).toSet();
  }

  /// Note une leçon comme abordée. Idempotent : répondre deux fois à la même
  /// leçon ne la compte pas deux fois, ce qui est indispensable à un score
  /// dérivé.
  Future<void> markAnswered(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(key) ?? const <String>[]).toSet();
    if (!current.add(lessonId)) {
      return;
    }
    await prefs.setStringList(key, current.toList(growable: false)..sort());
  }
}

final answeredLessonsStoreProvider = Provider<AnsweredLessonsStore>(
  (ref) => const AnsweredLessonsStore(),
);
