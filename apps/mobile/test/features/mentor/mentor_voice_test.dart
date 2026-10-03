import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_voice.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chaque voix du Mentor SONNE autrement : c'est ce que la personne choisit.
void main() {
  test('les quatre voix et la neutre se distinguent toutes à l’oreille', () {
    final reglages = {
      for (final style in [null, ...MentorStyle.values])
        (mentorVoiceFor(style).pitch, mentorVoiceFor(style).rate),
    };
    expect(reglages, hasLength(MentorStyle.values.length + 1));
  });

  test('aucun style choisi : la voix du moteur, au débit normal', () {
    final neutre = mentorVoiceFor(null);
    expect(neutre.pitch, 1);
    expect(neutre.rate, 0.5);
  });

  test('chaque réglage reste dans ce que les deux moteurs acceptent', () {
    for (final style in [null, ...MentorStyle.values]) {
      final voix = mentorVoiceFor(style);
      expect(voix.pitch, inInclusiveRange(0.5, 2), reason: '$style');
      expect(voix.rate, inInclusiveRange(0.3, 0.7), reason: '$style');
      expect(voix.timbre, greaterThanOrEqualTo(0), reason: '$style');
    }
  });

  test('les deux voix les plus proches ne partagent pas le même timbre', () {
    // Exigeant et Athlète ont un débit voisin : le timbre les sépare de
    // Bienveillant et Philosophe.
    expect(
      mentorVoiceFor(MentorStyle.exigeant).timbre,
      isNot(mentorVoiceFor(MentorStyle.bienveillant).timbre),
    );
    expect(
      mentorVoiceFor(MentorStyle.athlete).timbre,
      isNot(mentorVoiceFor(MentorStyle.philosophe).timbre),
    );
  });
}
