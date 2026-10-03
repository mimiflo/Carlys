import 'mentor_voice.dart';

/// La bouche du Mentor : dire un texte à voix haute, ou se taire.
///
/// Un port, pour que le domaine et les tests ignorent tout du greffon de
/// synthèse vocale (`data/flutter_tts_mentor_speaker.dart`).
abstract interface class MentorSpeaker {
  /// Dit [text] avec [voice] ; le futur se termine quand la phrase est dite
  /// ou interrompue. Lève [MentorSpeechUnavailable] quand le téléphone n'a
  /// pas de voix française.
  Future<void> speak(String text, MentorVoice voice);

  /// Coupe la phrase en cours ; sans effet s'il se tait déjà.
  Future<void> stop();
}

/// Ce qu'il est advenu d'une phrase demandée.
enum MentorSpeechOutcome {
  /// Dite, ou interrompue par un arrêt voulu.
  dite,

  /// Le téléphone n'a pas de voix française hors ligne.
  sansVoixFrancaise,

  /// Le moteur de synthèse a échoué pour une autre raison.
  echec,
}

/// Le téléphone ne sait pas parler français (aucune voix installée, ou
/// moteur de synthèse coupé).
class MentorSpeechUnavailable implements Exception {
  const MentorSpeechUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'MentorSpeechUnavailable: $reason';
}
