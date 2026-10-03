import 'entities/mentor_style.dart';

/// Comment une voix du Mentor SONNE, en réglages de synthèse vocale.
///
/// Le style décide déjà de ce que le Mentor écrit (côté serveur, et dans
/// `mentorWordCatalog`) ; ceci décide de la façon dont il le DIT. Trois
/// réglages, que les deux moteurs du téléphone comprennent de la même façon :
///
/// - [pitch] : la hauteur, 1 pour la voix du moteur (0,5 à 2) ;
/// - [rate] : le débit, 0,5 pour le débit normal (0 à 1) ;
/// - [timbre] : le rang de la voix française du téléphone à prendre, parmi
///   celles qu'il propose, rangées par nom. Deux rangs, pour que deux voix
///   proches par le ton ne partagent pas aussi le timbre — sur un téléphone
///   qui n'en a qu'une, tous les rangs la désignent.
class MentorVoice {
  const MentorVoice({
    required this.pitch,
    required this.rate,
    required this.timbre,
  });

  final double pitch;
  final double rate;
  final int timbre;
}

/// La voix de chaque style, et la voix neutre du coach tant que rien n'est
/// choisi. Le contraste se joue sur le débit et la hauteur ensemble : la
/// chaleur lente, la fermeté nette, l'énergie rapide, la gravité posée.
MentorVoice mentorVoiceFor(MentorStyle? style) => switch (style) {
  null => const MentorVoice(pitch: 1, rate: 0.5, timbre: 0),
  MentorStyle.bienveillant => const MentorVoice(
    pitch: 1.1,
    rate: 0.46,
    timbre: 0,
  ),
  MentorStyle.exigeant => const MentorVoice(pitch: 0.9, rate: 0.54, timbre: 1),
  MentorStyle.athlete => const MentorVoice(pitch: 1.05, rate: 0.6, timbre: 1),
  MentorStyle.philosophe => const MentorVoice(
    pitch: 0.82,
    rate: 0.42,
    timbre: 0,
  ),
};
