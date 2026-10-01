/// Le bonjour du coach, à l'ouverture de l'écran.
///
/// FONCTION PURE, écrite par l'appli et JAMAIS par le modèle : sur le
/// serveur, le modèle tourne sur le processeur, et un bonjour généré
/// coûterait de 20 à 90 secondes de calcul à CHAQUE ouverture, en prenant la
/// place de vraies questions dans la file. Il n'est ni archivé ni envoyé au
/// modèle : c'est un accueil, pas un message du fil.
///
/// Il parle à la voix du Mentor quand elle est choisie, et se règle sur le
/// texte brut du coach : pas de Markdown, pas de tiret long.
library;

import '../../../mentor/domain/entities/mentor_style.dart';

/// Le bonjour et sa place : il s'insère après les [after] messages que le
/// fil comptait à l'ouverture, et y reste pendant la visite.
class CoachGreeting {
  const CoachGreeting({
    required this.text,
    required this.after,
    required this.at,
  });

  final String text;
  final int after;

  /// L'ouverture. Son « Réfléchit… » ne se joue qu'une fois, à partir d'ici :
  /// une bulle recréée ensuite (le fil s'allonge, on défile) arrive déjà
  /// écrite, au lieu de rejouer l'attente à côté d'une vraie réponse.
  final DateTime at;
}

/// La présentation, à la première visite : ce que le coach sait faire.
/// (Ce qu'il lit, l'encart au-dessus le dit déjà.)
const String _intro =
    'Je suis ton coach. Demande-moi d’adapter ta séance du jour, de te '
    'proposer un programme, ou un conseil pour progresser.';

/// Ce qui suit la présentation, à la voix du Mentor.
const Map<MentorStyle?, String> _firstVisit = {
  null: 'Par quoi on commence ?',
  MentorStyle.bienveillant:
      'On avance à ton rythme : par quoi veux-tu '
      'commencer ?',
  MentorStyle.exigeant: 'Dis-moi ton objectif, et on s’y met.',
  MentorStyle.athlete:
      'Dis-moi ce que tu as en tête pour ta prochaine '
      'séance.',
  MentorStyle.philosophe:
      'Commençons par ce qui compte pour toi : quel est '
      'ton objectif ?',
};

/// Le retour dans une conversation déjà commencée.
const Map<MentorStyle?, String> _returning = {
  null:
      'On reprend où on s’était arrêtés ? Dis-moi ce que tu veux '
      'travailler aujourd’hui.',
  MentorStyle.bienveillant:
      'Content de te revoir. Dis-moi comment tu te '
      'sens, et on regarde ensemble ce qui te ferait du bien aujourd’hui.',
  MentorStyle.exigeant:
      'On ne perd pas de temps : qu’est-ce qu’on '
      'travaille aujourd’hui ?',
  MentorStyle.athlete:
      'Prêt pour la suite ? Donne-moi ta séance du jour, '
      'je t’aide à la caler.',
  MentorStyle.philosophe:
      'Chaque retour ici compte dans la durée. De quoi '
      'veux-tu parler aujourd’hui ?',
};

/// Le bonjour : « Bonjour » de 5 h à 18 h, « Bonsoir » ensuite, au PRÉNOM
/// seul (le premier mot du nom affiché), et rien plutôt qu'un nom vide.
String coachGreeting({
  required String? displayName,
  required MentorStyle? style,
  required bool returning,
  required DateTime now,
}) {
  final hello = now.hour >= 5 && now.hour < 18 ? 'Bonjour' : 'Bonsoir';
  final words = (displayName ?? '').trim().split(RegExp(r'\s+'));
  final name = words.first.isEmpty ? '' : ' ${words.first}';
  final body = returning
      ? _returning[style]!
      : '$_intro ${_firstVisit[style]!}';
  return '$hello$name ! $body';
}

/// Le jour LOCAL tel que le bonjour le retient : « 2026-10-01 ».
String greetingDay(DateTime now) {
  final day = now.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

/// Un bonjour par jour AU PLUS : pas une seconde fois en rouvrant l'écran,
/// et pas du tout quand la conversation du jour est déjà lancée.
bool shouldGreet({
  required String? lastGreetedDay,
  required bool wroteToday,
  required DateTime now,
}) => !wroteToday && lastGreetedDay != greetingDay(now);
