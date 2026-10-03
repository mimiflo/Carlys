import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../data/flutter_tts_mentor_speaker.dart';
import '../../domain/entities/mentor_style.dart';
import '../../domain/mentor_speaker.dart';
import '../../domain/mentor_voice.dart';
import '../providers/mentor_providers.dart';

/// Ce que le Mentor dit en ce moment : la CLÉ de la phrase en cours (le mot
/// du moment, une réponse du coach…), ou `null` quand il se tait. Un seul
/// texte à la fois : en dire un autre coupe le premier.
///
/// La voix est celle du style choisi, sauf [style] passé explicitement —
/// l'aperçu d'une voix qu'on n'a pas encore choisie.
class MentorSpeechController extends Notifier<String?> {
  static const _logger = AppLogger('MentorSpeech');

  @override
  String? build() => null;

  MentorSpeaker get _speaker => ref.read(mentorSpeakerProvider);

  /// Dit [text] ; l'issue dit pourquoi il n'a pas parlé, s'il n'a pas parlé
  /// — l'appelant le dit à la personne.
  Future<MentorSpeechOutcome> say(
    String key,
    String text, {
    MentorStyle? style,
  }) async {
    final voice = mentorVoiceFor(style ?? ref.read(currentMentorStyleProvider));
    state = key;
    try {
      await _speaker.speak(text, voice);
      return MentorSpeechOutcome.dite;
    } on MentorSpeechUnavailable catch (error) {
      _logger.warning('Synthèse vocale indisponible', error: error);
      return MentorSpeechOutcome.sansVoixFrancaise;
    } on Exception catch (error) {
      _logger.warning('La phrase n’a pas pu être dite', error: error);
      return MentorSpeechOutcome.echec;
    } finally {
      // Fini, coupé ou raté : il se tait — sauf si une autre phrase a pris
      // la place entre-temps.
      if (state == key) {
        state = null;
      }
    }
  }

  /// Le geste du bouton : écouter, ou arrêter ce qui est en train d'être dit.
  Future<MentorSpeechOutcome> toggle(
    String key,
    String text, {
    MentorStyle? style,
  }) async {
    if (state == key) {
      await stop();
      return MentorSpeechOutcome.dite;
    }
    return say(key, text, style: style);
  }

  Future<void> stop() async {
    state = null;
    try {
      await _speaker.stop();
    } on Exception catch (error) {
      _logger.warning('La voix n’a pas pu être coupée', error: error);
    }
  }
}

final mentorSpeechControllerProvider =
    NotifierProvider<MentorSpeechController, String?>(
      MentorSpeechController.new,
    );
