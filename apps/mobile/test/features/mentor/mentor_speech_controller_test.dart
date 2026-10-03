import 'package:carlys_mobile/features/mentor/data/flutter_tts_mentor_speaker.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_speaker.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_voice.dart';
import 'package:carlys_mobile/features/mentor/presentation/controllers/mentor_speech_controller.dart';
import 'package:carlys_mobile/features/mentor/presentation/providers/mentor_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_mentor_speaker.dart';

/// Ce que le Mentor dit, de quelle voix, et quand il se tait.
void main() {
  late FakeMentorSpeaker bouche;

  ProviderContainer monter({MentorStyle? style}) {
    bouche = FakeMentorSpeaker();
    final container = ProviderContainer(
      overrides: [
        mentorSpeakerProvider.overrideWithValue(bouche),
        currentMentorStyleProvider.overrideWithValue(style),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('il parle de la voix CHOISIE, et se tait une fois dit', () async {
    final container = monter(style: MentorStyle.philosophe);
    final speech = container.read(mentorSpeechControllerProvider.notifier);

    final dit = speech.say('mot', 'Prends de la hauteur.');
    expect(container.read(mentorSpeechControllerProvider), 'mot');
    expect(bouche.dits.single.$1, 'Prends de la hauteur.');
    expect(
      bouche.dits.single.$2.pitch,
      mentorVoiceFor(MentorStyle.philosophe).pitch,
    );

    bouche.finir();
    expect(await dit, MentorSpeechOutcome.dite);
    expect(container.read(mentorSpeechControllerProvider), isNull);
  });

  test('l’aperçu d’une voix pas encore choisie parle de CETTE voix', () async {
    final container = monter();
    final speech = container.read(mentorSpeechControllerProvider.notifier);

    final dit = speech.say('apercu', 'Allez !', style: MentorStyle.athlete);
    expect(
      bouche.dits.single.$2.rate,
      mentorVoiceFor(MentorStyle.athlete).rate,
    );
    bouche.finir();
    await dit;
  });

  test('le même bouton : écouter, puis arrêter', () async {
    final container = monter();
    final speech = container.read(mentorSpeechControllerProvider.notifier);

    final dit = speech.toggle('mot', 'Un mot.');
    expect(container.read(mentorSpeechControllerProvider), 'mot');

    await speech.toggle('mot', 'Un mot.');
    expect(bouche.arrets, 1);
    expect(container.read(mentorSpeechControllerProvider), isNull);
    expect(await dit, MentorSpeechOutcome.dite);
  });

  test('une autre phrase prend la place de la première', () async {
    final container = monter();
    final speech = container.read(mentorSpeechControllerProvider.notifier);

    final premiere = speech.say('a', 'Premier.');
    final seconde = speech.say('b', 'Second.');
    await premiere;
    // La première, interrompue, ne remet PAS le silence : la seconde parle.
    expect(container.read(mentorSpeechControllerProvider), 'b');

    bouche.finir();
    await seconde;
    expect(container.read(mentorSpeechControllerProvider), isNull);
  });

  test(
    'pas de voix française sur le téléphone : il le dit, et se tait',
    () async {
      final container = monter();
      bouche.disponible = false;

      final dit = await container
          .read(mentorSpeechControllerProvider.notifier)
          .say('mot', 'Un mot.');

      expect(dit, MentorSpeechOutcome.sansVoixFrancaise);
      expect(container.read(mentorSpeechControllerProvider), isNull);
    },
  );
}
