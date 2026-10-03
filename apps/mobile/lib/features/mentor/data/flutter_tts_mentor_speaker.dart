import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/mentor_speaker.dart';
import '../domain/mentor_voice.dart';

/// Le Mentor parle par la synthèse vocale du TÉLÉPHONE (Android
/// TextToSpeech, iOS AVSpeechSynthesizer) : hors ligne, sans serveur, et le
/// texte ne quitte pas l'appareil.
///
/// Les voix françaises sont lues une fois, rangées par nom ; celles qui
/// exigent le réseau (Android) sont écartées, et s'il ne reste QUE celles-là
/// le Mentor se dit indisponible plutôt que d'envoyer le texte en ligne.
///
/// La fin d'une phrase s'attend ICI, pas par `awaitSpeakCompletion` du
/// greffon : sur iOS, un arrêt ne libère jamais cette attente-là (et une
/// erreur du moteur Android non plus) — le bouton resterait sur « Arrêter ».
/// La phrase finit donc sur l'un des signaux du moteur (fin, annulation,
/// erreur) OU sur [stop]. Un compteur écarte la phrase dépassée : arrêtée
/// pendant la préparation des voix, ou remplacée par une autre.
class FlutterTtsMentorSpeaker implements MentorSpeaker {
  FlutterTtsMentorSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<List<Map<String, String>>>? _voices;
  Completer<void>? _phrase;
  int _tour = 0;

  Future<List<Map<String, String>>> _prepare() => _voices ??= () async {
    if (await _tts.isLanguageAvailable('fr-FR') != true) {
      throw const MentorSpeechUnavailable('aucune voix française');
    }
    await _tts.setLanguage('fr-FR');
    _tts
      ..setCompletionHandler(_finir)
      ..setCancelHandler(_finir)
      ..setErrorHandler((_) => _finir());
    final raw = await _tts.getVoices;
    final francaises = [
      if (raw is List)
        for (final voice in raw)
          if (voice is Map &&
              '${voice['locale']}'.toLowerCase().startsWith('fr'))
            voice,
    ];
    final horsLigne = <Map<String, String>>[
      for (final voice in francaises)
        if ('${voice['network_required']}' != '1')
          {'name': '${voice['name']}', 'locale': '${voice['locale']}'},
    ]..sort((a, b) => a['name']!.compareTo(b['name']!));
    if (francaises.isNotEmpty && horsLigne.isEmpty) {
      throw const MentorSpeechUnavailable('voix françaises en ligne seulement');
    }
    return horsLigne;
  }();

  void _finir() {
    final phrase = _phrase;
    _phrase = null;
    if (phrase != null && !phrase.isCompleted) phrase.complete();
  }

  @override
  Future<void> speak(String text, MentorVoice voice) async {
    final tour = ++_tour;
    final List<Map<String, String>> voices;
    try {
      voices = await _prepare();
    } catch (_) {
      // Pas de préparation gardée en échec : une voix française s'installe,
      // un moteur se rallume — la prochaine demande réessaie.
      _voices = null;
      rethrow;
    }
    if (tour != _tour) return; // arrêtée, ou remplacée, pendant la préparation
    await _tts.stop();
    _finir();
    if (voices.isNotEmpty) {
      await _tts.setVoice(voices[voice.timbre % voices.length]);
    }
    await _tts.setPitch(voice.pitch);
    await _tts.setSpeechRate(voice.rate);
    if (tour != _tour) return;
    final phrase = _phrase = Completer<void>();
    await _tts.speak(text);
    return phrase.future;
  }

  @override
  Future<void> stop() async {
    _tour++;
    _finir();
    await _tts.stop();
  }
}

/// Non auto-disposé : une phrase commencée sur une feuille continue après
/// sa fermeture si personne ne la coupe, et c'est le contrôleur qui la coupe.
final mentorSpeakerProvider = Provider<MentorSpeaker>((ref) {
  return FlutterTtsMentorSpeaker();
});
