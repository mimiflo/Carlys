/// Le POURQUOI des chiffres de l'écran Nutrition.
///
/// Ces explications existaient déjà, mais en commentaires TypeScript dans
/// `metabolism.calculator.ts` : le serveur savait, personne ne lisait.
/// L'écran affichait « IMC 27,3 » et « Surpoids » sans un mot.
///
/// C'est du CONTENU, pas du calcul : rien n'y est recalculé, on y dit ce que
/// le serveur a fait. Toute évolution de `metabolism.calculator.ts` — un
/// facteur d'activité, un ratio de lipides — doit se refléter ici, sinon
/// l'explication ment. Un test verrouille ce couplage en LISANT le
/// calculateur du serveur.
library;

import '../../../core/explanations/explanation.dart';

/// Le catalogue, une entrée par donnée que l'application affiche.
///
/// Rien n'y est inventé : chaque nombre cité se retrouve dans
/// `apps/api/src/modules/nutrition/application/metabolism.calculator.ts`.
abstract final class NutritionExplanations {
  static const Explanation imc = Explanation(
    titre: 'IMC',
    cequeCest:
        'Un rapport entre ton poids et ta taille, et rien de plus. Il sert à '
        'situer une population, pas à juger une personne.',
    douCaSort:
        'Poids en kilos divisé par la taille en mètres, au carré. Les seuils '
        'sont ceux de l’OMS : moins de 18,5 insuffisance pondérale, de 18,5 à '
        '25 corpulence normale, de 25 à 30 surpoids, 30 et au-delà obésité.',
    cequeCaNeDitPas:
        'Il ignore complètement ce dont ton poids est fait. À taille et poids '
        'égaux, une personne très musclée et une personne sédentaire ont le '
        'même IMC. Si tu pratiques la force depuis des années, il te classera '
        'souvent en surpoids : ce n’est pas toi qui as tort, c’est lui qui ne '
        'sait pas faire la différence entre du muscle et de la graisse.',
  );

  static const Explanation metabolismeDeBase = Explanation(
    titre: 'Métabolisme de base',
    cequeCest:
        'Ce que ton corps dépense au repos complet, rien qu’à rester en vie : '
        'respirer, tenir sa température, faire battre le cœur.',
    douCaSort:
        'La formule de Mifflin-St Jeor : 10 × ton poids, plus 6,25 × ta '
        'taille en centimètres, moins 5 × ton âge, puis +5 si tu es un homme '
        'et −161 si tu es une femme.',
    cequeCaNeDitPas:
        'Il bouge quand tu bouges : le poids et le muscle le font monter, '
        'l’âge le fait descendre. C’est pour ça que corriger une pesée '
        'déplace tous les chiffres qui en dépendent : ce n’est pas un bug, '
        'c’est la conséquence.',
  );

  static const Explanation depenseEnergetique = Explanation(
    titre: 'Dépense énergétique',
    cequeCest:
        'Ton métabolisme de base, plus tout ce que tu fais de ta journée : '
        'marcher, travailler, t’entraîner.',
    douCaSort:
        'Le métabolisme de base multiplié par un facteur d’activité, celui '
        'que tu as choisi dans ton profil : 1,2 si tu es sédentaire, 1,375 '
        'peu actif, 1,55 modérément actif, 1,725 actif, 1,9 très actif.',
    cequeCaNeDitPas:
        'Ce n’est pas une mesure, c’est une estimation à partir de ce que tu '
        'as déclaré. Si ton poids ne suit pas la trajectoire annoncée pendant '
        'deux ou trois semaines, c’est le facteur d’activité qu’il faut '
        'revoir avant de douter de la balance.',
  );

  static const Explanation caloriesCibles = Explanation(
    titre: 'Objectif calorique',
    cequeCest: 'Ta dépense estimée, ajustée à l’objectif que tu as choisi.',
    douCaSort:
        'Perte de gras : la dépense moins 15 %. Maintien : la dépense telle '
        'quelle. Prise de muscle : la dépense plus 10 %. Des écarts modérés, '
        'et c’est exprès : un déficit plus creux fait perdre du muscle avec '
        'le gras. Et le résultat ne descend jamais sous un plancher : 1200 '
        'kcal pour une femme, 1500 kcal pour un homme.',
    cequeCaNeDitPas:
        'Cet objectif n’est pas figé. En perdant du poids tu baisses ton '
        'métabolisme de base, donc ta dépense, donc ta cible : elle descend '
        'avec toi. Un chiffre calculé une fois pour toutes serait faux au '
        'bout d’un mois. Si le plancher s’applique, la multiplication '
        'ci-dessus ne décrit plus ta cible : c’est le plancher qui la fixe, '
        'et perte de gras et maintien se rejoignent.',
  );

  /// Ce que veut dire une cible RELEVÉE au plancher.
  ///
  /// Une entrée séparée, parce que c'est une situation, pas une donnée : elle
  /// ne paraît que quand le serveur pose `targetKcalFloored`, et elle répond
  /// à la question que le bandeau fait naître.
  static const Explanation plancherCalorique = Explanation(
    titre: 'Pourquoi ta cible a été relevée',
    cequeCest:
        'Ton objectif calculé tombait sous le seuil bas d’un régime qu’on '
        'suit sans médecin. Carlys l’a remonté à ce seuil.',
    douCaSort:
        'Le plancher vaut 1200 kcal pour une femme et 1500 kcal pour un '
        'homme. Ta dépense estimée multipliée par ton objectif donnait moins '
        'que ça, donc c’est le plancher qui s’affiche.',
    cequeCaNeDitPas:
        'Il ne dit pas que descendre plus bas est impossible, il dit que ça '
        'ne se décide pas tout seul : sous ce seuil, couvrir ses vitamines '
        'et ses minéraux devient difficile, et c’est une affaire de '
        'professionnel de santé, pas d’application. Il ne dit pas non plus '
        'que tu dois manger 1200 kcal : si tu n’as pas faim à ce niveau, '
        'c’est le profil qu’il faut revoir, pas l’appétit.',
  );

  static const Explanation proteines = Explanation(
    titre: 'Protéines',
    cequeCest: 'De quoi construire et surtout CONSERVER ton muscle.',
    douCaSort:
        'Rapportées à ton poids : 2 g par kilo en perte de gras, 1,8 en prise '
        'de muscle, 1,6 en maintien.',
    cequeCaNeDitPas:
        'La part la plus haute est en PERTE, ce qui surprend souvent : quand '
        'l’énergie manque, le corps puise aussi dans le muscle, et la '
        'protéine est ce qui l’en dissuade.',
  );

  static const Explanation lipides = Explanation(
    titre: 'Lipides',
    cequeCest: 'Le gras alimentaire : indispensable, pas facultatif.',
    douCaSort:
        'Un quart de ton objectif calorique, converti en grammes (9 kcal par gramme).',
    cequeCaNeDitPas:
        'Descendre nettement sous ce quart se paie : les lipides portent les '
        'vitamines A, D, E et K et servent de matière première aux hormones. '
        'Couper le gras n’est pas une stratégie, c’est une carence différée.',
  );

  static const Explanation glucides = Explanation(
    titre: 'Glucides',
    cequeCest: 'Ton carburant d’effort, celui que tu brûles le plus vite.',
    douCaSort:
        'Ce qui reste. Une fois les protéines et les lipides posés, tout le '
        'solde de l’objectif calorique part en glucides (4 kcal par gramme).',
    cequeCaNeDitPas:
        'C’est un solde, donc la variable d’ajustement : si ta cible baisse, '
        'ce sont les glucides qui reculent en premier, pas les protéines.',
  );

  static const Explanation eau = Explanation(
    titre: 'Hydratation',
    cequeCest: 'La quantité d’eau visée sur une journée ordinaire.',
    douCaSort: '35 millilitres par kilo de poids corporel.',
    cequeCaNeDitPas:
        'C’est une base, pas un plafond : la chaleur, l’altitude et une '
        'séance longue augmentent le besoin sans que l’application le sache. '
        'Le compteur est local à cet appareil et repart à zéro chaque nuit.',
  );

  /// L'explication la plus importante est celle d'une donnée ABSENTE.
  ///
  /// La spécification demande d'expliquer la masse musculaire et la masse
  /// grasse. Carlys ne les calcule pas — et le dire, avec la raison, est
  /// plus pédagogique que d'afficher une estimation qui se trompe.
  static const Explanation masseGrasseEtMusculaire = Explanation(
    titre: 'Masse grasse et masse musculaire',
    cequeCest:
        'La part de ton poids qui est du gras, et celle qui est du muscle. '
        'Carlys ne les affiche pas.',
    douCaSort:
        'Nulle part : aucune des deux ne se déduit du poids et de la taille. '
        'Les formules qui prétendent le faire partent de l’IMC et héritent '
        'donc de son défaut : elles se trompent surtout chez les gens qui '
        's’entraînent, c’est-à-dire ici.',
    cequeCaNeDitPas:
        'Une balance à impédance en donne, mais ses valeurs bougent avec ton '
        'hydratation, l’heure et le repas précédent : elles sont utiles pour '
        'suivre une TENDANCE sur le même appareil, jamais pour un chiffre '
        'absolu. Ce que Carlys suit à la place, et qui se mesure vraiment : '
        'ton poids dans le temps, tes charges, et tes photos.',
  );

  /// Toutes les explications, pour les tests d'intégrité.
  static const List<Explanation> toutes = [
    imc,
    metabolismeDeBase,
    depenseEnergetique,
    caloriesCibles,
    plancherCalorique,
    proteines,
    lipides,
    glucides,
    eau,
    masseGrasseEtMusculaire,
  ];
}
