import 'dart:async';

import 'package:carlys_mobile/features/mentor/domain/mentor_speaker.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_voice.dart';

/// La bouche du Mentor, pour les tests : elle note ce qu'on lui fait dire,
/// et ne finit sa phrase que quand le test le décide ([finir]).
class FakeMentorSpeaker implements MentorSpeaker {
  FakeMentorSpeaker({this.disponible = true});

  bool disponible;
  final List<(String, MentorVoice)> dits = [];
  int arrets = 0;
  Completer<void>? _phrase;

  @override
  Future<void> speak(String text, MentorVoice voice) {
    if (!disponible) {
      return Future.error(const MentorSpeechUnavailable('test'));
    }
    dits.add((text, voice));
    _phrase?.complete();
    return (_phrase = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    arrets++;
    finir();
  }

  /// La phrase en cours se termine (dite, ou coupée).
  void finir() {
    final phrase = _phrase;
    _phrase = null;
    if (phrase != null && !phrase.isCompleted) phrase.complete();
  }
}
