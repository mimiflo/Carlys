import 'dart:async';

import 'package:carlys_mobile/features/mentor/data/flutter_tts_mentor_speaker.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_speaker.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Le moteur du téléphone, simulé : ce que l'adaptateur lui demande.
class _FakeTts extends FlutterTts {
  _FakeTts({this.francais = true, this.voix = const [], this.finitSeul = true});

  bool francais;

  /// Le moteur signale-t-il lui-même la fin de phrase ? Faux : la phrase ne
  /// finit que par un arrêt, SANS signal — ce que fait iOS.
  final bool finitSeul;
  final List<Map<String, String>> voix;
  final List<String> appels = [];
  Map<String, String>? voixPosee;
  double? hauteur;
  double? debit;

  @override
  Future<dynamic> isLanguageAvailable(String language) async => francais;

  @override
  Future<dynamic> setLanguage(String language) async => appels.add('fr');

  @override
  Future<dynamic> get getVoices async => voix;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async =>
      voixPosee = voice;

  @override
  Future<dynamic> setPitch(double pitch) async => hauteur = pitch;

  @override
  Future<dynamic> setSpeechRate(double rate) async => debit = rate;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    appels.add('dit:$text');
    if (finitSeul) scheduleMicrotask(() => completionHandler?.call());
  }

  @override
  Future<dynamic> stop() async => appels.add('stop');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const voix = MentorVoice(pitch: 0.9, rate: 0.54, timbre: 1);

  test(
    'voix françaises hors réseau, rangées par nom ; le timbre choisit',
    () async {
      final tts = _FakeTts(
        voix: const [
          {'name': 'fr-fr-x-zzz', 'locale': 'fr-FR', 'network_required': '0'},
          {'name': 'en-us-x-aaa', 'locale': 'en-US', 'network_required': '0'},
          {'name': 'fr-fr-x-net', 'locale': 'fr-FR', 'network_required': '1'},
          {'name': 'fr-fr-x-aaa', 'locale': 'fr-FR', 'network_required': '0'},
        ],
      );
      await FlutterTtsMentorSpeaker(tts).speak('Debout.', voix);

      // Rang 1 parmi [aaa, zzz] : l'anglaise et celle du réseau sont écartées.
      expect(tts.voixPosee, {'name': 'fr-fr-x-zzz', 'locale': 'fr-FR'});
      expect(tts.hauteur, 0.9);
      expect(tts.debit, 0.54);
      expect(tts.appels.last, 'dit:Debout.');
    },
  );

  test('une seule voix française : tous les timbres la désignent', () async {
    final tts = _FakeTts(
      voix: const [
        {'name': 'Amélie', 'locale': 'fr-CA'},
      ],
    );
    await FlutterTtsMentorSpeaker(tts).speak('Bonjour.', voix);
    expect(tts.voixPosee?['name'], 'Amélie');
  });

  test(
    'pas de français : refus nommé, puis nouvel essai une fois installé',
    () async {
      final tts = _FakeTts(francais: false);
      final speaker = FlutterTtsMentorSpeaker(tts);

      await expectLater(
        speaker.speak('Bonjour.', voix),
        throwsA(isA<MentorSpeechUnavailable>()),
      );

      tts.francais = true;
      await speaker.speak('Bonjour.', voix);
      expect(tts.appels.last, 'dit:Bonjour.');
    },
  );

  test(
    'voix françaises EN LIGNE seulement : indisponible, rien ne part',
    () async {
      final tts = _FakeTts(
        voix: const [
          {'name': 'fr-fr-x-net', 'locale': 'fr-FR', 'network_required': '1'},
        ],
      );
      await expectLater(
        FlutterTtsMentorSpeaker(tts).speak('Bonjour.', voix),
        throwsA(isA<MentorSpeechUnavailable>()),
      );
      expect(tts.appels.where((a) => a.startsWith('dit:')), isEmpty);
    },
  );

  test('un arrêt LIBÈRE la phrase, même sans signal du moteur (iOS)', () async {
    final tts = _FakeTts(finitSeul: false);
    final speaker = FlutterTtsMentorSpeaker(tts);

    var finie = false;
    unawaited(speaker.speak('Long discours.', voix).then((_) => finie = true));
    await pumpEventQueue();
    expect(finie, isFalse, reason: 'Elle parle encore.');

    await speaker.stop();
    await pumpEventQueue();
    expect(finie, isTrue);
  });

  test('arrêtée pendant la préparation des voix : jamais dite', () async {
    final tts = _FakeTts();
    final speaker = FlutterTtsMentorSpeaker(tts);

    final phrase = speaker.speak('Trop tard.', voix);
    await speaker.stop();
    await phrase;
    expect(tts.appels.where((a) => a.startsWith('dit:')), isEmpty);
  });
}
