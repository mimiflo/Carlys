/// Recueil des maximes Carlys — **contenu éditorial de l'application**.
///
/// Ce n'est pas une donnée utilisateur déguisée ni un faux backend : ce sont
/// les mots du produit, au même titre que ses libellés d'écran. Ils vivent
/// donc dans l'application, ce qui garantit qu'une maxime s'affiche **hors
/// ligne, dès le premier lancement**, sans appel réseau — la règle
/// offline-first vaut aussi pour ce qui motive.
///
/// Rien n'est attribué à une personne réelle : ce sont des maximes maison.
/// Prêter une phrase inventée à un athlète ou à un auteur serait une citation
/// fabriquée, donc un mensonge affiché à l'utilisateur.
///
/// Les entrées sont **entrelacées par valeur** (dépassement, connaissance,
/// maîtrise, constance, équilibre, puis on recommence) : comme la sélection
/// avance d'un cran par jour, deux jours consécutifs ne servent jamais la même
/// valeur.
library;

import '../domain/entities/daily_quote.dart';

const List<DailyQuote> carlysQuotes = [
  // — Cycle 1
  DailyQuote(
    text: 'La dernière répétition est celle qui te change. '
        'Les autres t’y amènent.',
    value: CarlysValue.depassement,
  ),
  DailyQuote(
    text: 'Un mouvement compris vaut dix mouvements imités.',
    value: CarlysValue.connaissance,
  ),
  DailyQuote(
    text: 'Contrôle la descente : c’est là que le muscle travaille le plus.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text: 'Trois séances tenues valent mieux que six prévues.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Le repos fait partie de l’entraînement, pas de son absence.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 2
  DailyQuote(
    text:
        'Tu ne cherches pas le confort. Tu cherches ce qu’il y a juste après.',
    value: CarlysValue.depassement,
  ),
  DailyQuote(
    text:
        'Note ce que tu fais : la mémoire arrange les chiffres, pas le carnet.',
    value: CarlysValue.connaissance,
  ),
  DailyQuote(
    text: 'La vitesse impressionne. Le contrôle transforme.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text: 'La régularité bat l’intensité sur la durée. Chaque fois.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Un corps qui récupère est un corps qui progresse.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 3
  DailyQuote(
    text: 'Une série de plus qu’hier suffit. C’est ça, progresser.',
    value: CarlysValue.depassement,
  ),
  DailyQuote(
    text: 'Ton corps te renseigne en continu. Apprends sa langue.',
    value: CarlysValue.connaissance,
  ),
  DailyQuote(
    text: 'L’amplitude complète avant la charge lourde. Toujours.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text: 'Le jour où tu n’as pas envie est celui qui compte double.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Tire autant que tu pousses : le corps n’a pas qu’une face avant.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 4
  DailyQuote(
    text: 'L’échec musculaire n’est pas un échec. C’est une information.',
    value: CarlysValue.depassement,
  ),
  DailyQuote(
    text: 'Un entraînement sans mesure reste une opinion.',
    value: CarlysValue.connaissance,
  ),
  DailyQuote(
    text: 'Le tempo est une charge invisible.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text: 'Une séance courte reste une séance. Zéro ne l’est pas.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Dors : c’est là que la séance d’aujourd’hui devient du muscle.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 5
  DailyQuote(
    text: 'Ce qui te semblait lourd il y a six mois est ton échauffement.',
    value: CarlysValue.depassement,
  ),
  DailyQuote(
    text: 'La technique n’est pas un détail : c’est le mouvement lui-même.',
    value: CarlysValue.connaissance,
  ),
  DailyQuote(
    text:
        'Maîtriser, c’est pouvoir s’arrêter à n’importe quel moment du geste.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text: 'Ce que tu répètes devient ce que tu es.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Mange pour ce que tu vas faire, pas pour ce que tu as fait.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 6
  DailyQuote(
    text: 'Vise la répétition que tu crois impossible : '
        'elle recule à chaque séance.',
    value: CarlysValue.depassement,
  ),
  DailyQuote(
    text: 'Comprends la charge avant de l’augmenter.',
    value: CarlysValue.connaissance,
  ),
  DailyQuote(
    text: 'Fais peu, fais-le parfaitement, recommence.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text: 'Ne romps pas la chaîne : même un maillon léger la prolonge.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Écoute la douleur. Elle a rarement tort.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 7
  DailyQuote(
    text: 'Le poids ne ment pas : il dit exactement où tu en es aujourd’hui.',
    value: CarlysValue.depassement,
  ),
  DailyQuote(
    text: 'Sache ce que tu fais, et pourquoi. Le reste suit.',
    value: CarlysValue.connaissance,
  ),
  DailyQuote(
    text: 'Ce n’est pas le poids que tu soulèves, '
        'c’est la façon dont tu le soulèves.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text: 'La forme se construit en semaines, pas en séances.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'La progression durable ne se paie pas en blessures.',
    value: CarlysValue.equilibre,
  ),
];

/// Maxime du jour, **déterministe** : la même toute la journée, différente
/// demain, identique sur tous les appareils de l'utilisateur.
///
/// L'index avance d'un cran par jour civil local, ce qui fait tourner le
/// recueil en [carlysQuotes.length] jours et change de valeur chaque matin.
DailyQuote quoteOfTheDay(DateTime day) {
  final index = _daysSinceEpoch(day) % carlysQuotes.length;
  return carlysQuotes[index];
}

/// Numéro de jour civil local. On repasse par `DateTime.utc` avec les seuls
/// champs de date : le décalage horaire et les changements d'heure ne peuvent
/// donc pas faire sauter — ou rejouer — une journée.
int _daysSinceEpoch(DateTime day) {
  final local = day.toLocal();
  return DateTime.utc(local.year, local.month, local.day)
      .difference(DateTime.utc(1970))
      .inDays;
}
