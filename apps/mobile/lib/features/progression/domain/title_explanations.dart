/// Ce que chaque TITRE veut dire.
///
/// L'application affichait « Apprenti » et « 4 / 5 PALIERS » sans qu'aucune
/// surface ne dise ce que ces mots signifient. `CarlysTitle` ne porte qu'un
/// libellé, un seuil et un chiffre romain : de la mécanique, pas du sens.
///
/// C'est du CONTENU, pas du calcul : rien n'est recalculé ici, on y dit ce
/// que le moteur fait. Les seuils cités viennent de [CarlysTitle] et un test
/// vérifie qu'ils n'en divergent pas.
///
/// ## Ce qui a failli être écrit, et qui était FAUX
///
/// Une première rédaction promettait que Maître demandait « les cinq axes qui
/// montent de concert » et qu'Architecte attestait de « séances réelles,
/// terminées ». Le barème rejoué dit le contraire, et c'est vérifiable :
///
/// - vingt leçons d'Academy et RIEN d'autre donnent 200 points, donc
///   Architecte, sans une seule séance ;
/// - huit semaines de séances closes sans aucune charge notée donnent 775
///   points, donc Maître, avec l'axe de performance encore EN ATTENTE ;
/// - une seule séance close avec des charges donne 350 points, donc
///   Architecte dès le premier jour.
///
/// Une explication qui promet plus que le barème n'exige est un mensonge
/// aimable, et c'est encore un mensonge. Les textes ci-dessous disent ce que
/// le moteur fait vraiment, y compris quand c'est moins flatteur.
///
/// Les noms d'énumération sont GELÉS : `reward_engine.dart` en dérive les
/// clés du journal. On explique les libellés, on ne les renomme pas.
library;

import '../../../core/explanations/explanation.dart';
import 'progression.dart';

/// Le catalogue des titres, une entrée par palier, plus le système lui-même.
abstract final class TitleExplanations {
  /// Ce qu'est le système de titres, avant de parler d'un palier.
  static const Explanation systeme = Explanation(
    titre: 'Les titres',
    cequeCest:
        'Cinq paliers qui résument ta pratique en un mot, d’Apprenti à '
        'Icône. Ils racontent un métier qui s’apprend, pas un niveau de jeu '
        'qui se farme.',
    douCaSort:
        'De cinq axes valant 200 points chacun, 1 000 en tout, et de cinq '
        'seuils : 0, 200, 420, 650 et 860. Les axes lisent tes faits réels : '
        'les semaines où tu reviens, vingt leçons d’Academy abordées quelle '
        'que soit la taille du pack, la tendance de tes charges sur quatre '
        'semaines, la part des séances commencées que tu mènes à leur terme, '
        'et un rythme de deux à quatre séances par semaine. Rien ne '
        's’additionne dans un compteur : tout se RECALCULE à chaque lecture.',
    cequeCaNeDitPas:
        'Ce n’est pas un classement : personne d’autre n’entre dans le '
        'calcul. Ce n’est pas non plus une réserve qui grossit à vie, puisque '
        'le total se recalcule : il redescend si tu t’arrêtes. Le palier que '
        'tu as ATTEINT, lui, reste gravé : le cran gravé de ta carte garde '
        'ton plus haut palier et le journal en garde la date. Enfin, aucun '
        'axe ne regarde au-delà de huit semaines : le titre ne peut pas dire '
        'depuis combien d’années tu t’entraînes.',
  );

  /// Le mot « rang », qui s'affiche sous deux formes sans jamais être défini.
  static const Explanation rang = Explanation(
    titre: 'Rang, chiffre romain, paliers',
    cequeCest:
        'La position de ton titre sur l’échelle, écrite de deux façons : le '
        'chiffre romain frappé sur ton sceau, et la fraction « n / 5 '
        'PALIERS » de ta carte. Les deux disent la même chose.',
    douCaSort:
        'Du rang du palier dans la liste, de I à V. Ce n’est pas un score : '
        'c’est un numéro d’ordre.',
    cequeCaNeDitPas:
        'Le cran gravé de ta carte suit ton palier le plus HAUT jamais '
        'atteint, pas celui du moment. C’est voulu : une interruption fait '
        'redescendre des points, elle ne reprend pas ce que tu as construit.',
  );

  static const Explanation apprenti = Explanation(
    titre: 'Apprenti',
    cequeCest:
        'Le palier de départ, celui que tout le monde porte le premier jour. '
        'Il dit que la pratique commence, rien d’autre.',
    douCaSort:
        'Du premier seuil, à 0 point : personne n’a besoin de le gagner. Les '
        'points arrivent ensuite des cinq axes, 200 chacun : constance, '
        'maîtrise, performance, discipline, équilibre.',
    cequeCaNeDitPas:
        'Il ne dit rien de ton niveau physique. Quelqu’un qui soulève lourd '
        'depuis dix ans et installe Carlys aujourd’hui porte exactement le '
        'même titre : l’application ne connaît encore aucun de ses faits. Et '
        'si tu l’as retrouvé après une pause, seul le titre PORTÉ est '
        'redescendu : le cran gravé de ta carte garde ton plus haut palier, '
        'et le journal en garde la date.',
  );

  static const Explanation architecte = Explanation(
    titre: 'Architecte',
    cequeCest:
        'Ta pratique a laissé des faits que l’application peut lire : des '
        'séances terminées, des leçons d’Academy, ou les deux. Elle existe '
        'en faits, plus seulement en intention.',
    douCaSort:
        'De 200 points sur 1 000, le premier palier qui se gagne. Un seul '
        'axe plein y suffit, et n’importe lequel : vingt leçons abordées le '
        'donnent sans une séance, et une seule séance terminée avec des '
        'charges le donne dès le premier jour.',
    cequeCaNeDitPas:
        'Il ne dit pas que ton programme est bon : Carlys mesure ce que tu '
        'fais, pas ce que tu aurais pu choisir. Et comme un seul axe suffit, '
        'deux Architectes peuvent n’avoir presque rien en commun : l’un a '
        'travaillé l’Academy, l’autre a terminé sa première séance, et le '
        'titre ne les départage pas.',
  );

  static const Explanation artisan = Explanation(
    titre: 'Artisan',
    cequeCest:
        'Le milieu du chemin : plusieurs axes tiennent en même temps, plus '
        'un seul poussé à fond.',
    douCaSort:
        'De 420 points sur 1 000, soit un peu plus de deux axes pleins. '
        'Chaque axe vaut 200 points et se recalcule sur des faits récents : '
        'semaines avec séance, leçons abordées, tendance des charges, part '
        'des séances menées à leur terme, nombre de séances hebdomadaires '
        'avec du repos entre elles.',
    cequeCaNeDitPas:
        'Deux axes pleins ouvrent déjà ce palier : il ne garantit pas que la '
        'constance en fasse partie. Il ne mesure pas non plus la force '
        'absolue, puisque l’axe de performance compare tes quatre dernières '
        'semaines aux quatre précédentes : progresser depuis 40 kg le '
        'remplit autant que progresser depuis 140. Et plus n’est pas mieux : '
        'au-delà de quatre séances par semaine, l’axe d’équilibre redescend, '
        'parce qu’il mesure la récupération.',
  );

  static const Explanation maitre = Explanation(
    titre: 'Maître',
    cequeCest:
        'Plusieurs axes tiennent ensemble et dans la durée, repos compris : '
        'ce n’est pas un pic, c’est une pratique qui se gouverne. Maître se '
        'dit d’un métier, jamais des gens.',
    douCaSort:
        'De 650 points sur 1 000. Trois axes pleins n’y suffisent pas, '
        'puisqu’ils n’en font que 600 : il en faut quatre, ou cinq qui '
        'montent ensemble.',
    cequeCaNeDitPas:
        'Ce n’est ni un brevet, ni une autorité sur qui que ce soit. Le '
        'titre ne lit ni ta technique, ni ta charge maximale : il lit une '
        'régularité, un volume, des leçons abordées et des séances closes. '
        'Quatre axes pleins l’ouvrent, donc un cinquième axe encore en '
        'attente ne l’empêche pas. Il se recalcule à chaque lecture et '
        'redescend si tu t’arrêtes, mais le journal garde la date où tu l’as '
        'atteint.',
  );

  static const Explanation icone = Explanation(
    titre: 'Icône',
    cequeCest:
        'Ta pratique tient sur tous les fronts à la fois, pas sur une seule '
        'semaine : revenir, comprendre, progresser, finir, récupérer.',
    douCaSort:
        'De 860 points sur 1 000, le dernier palier : environ 172 points de '
        'moyenne sur chacun des cinq axes. C’est le seul palier où aucun axe '
        'ne peut rester vide, puisque quatre axes pleins n’en font que 800. '
        'Le seuil reste volontairement sous le maximum : un titre '
        'inatteignable serait une carotte, pas un palier.',
    cequeCaNeDitPas:
        'Ce n’est pas un classement : aucun autre pratiquant n’entre dans le '
        'calcul, et personne ne recule d’un rang parce que tu montes. Ce '
        'n’est pas une arrivée non plus : les 140 points restants existent '
        'toujours. Et il ne dit pas depuis combien d’années tu t’entraînes, '
        'puisque aucun axe ne regarde au-delà de huit semaines. Ce qui ne se '
        'reprend jamais, c’est le cran gravé de ta carte et la date inscrite '
        'au journal.',
  );

  /// L'explication d'un palier.
  static Explanation of(CarlysTitle titre) => switch (titre) {
    CarlysTitle.apprenti => apprenti,
    CarlysTitle.architecte => architecte,
    CarlysTitle.artisan => artisan,
    CarlysTitle.maitre => maitre,
    CarlysTitle.icone => icone,
  };

  /// Toutes les explications, pour les tests d'intégrité.
  static const List<Explanation> toutes = [
    systeme,
    rang,
    apprenti,
    architecte,
    artisan,
    maitre,
    icone,
  ];
}
