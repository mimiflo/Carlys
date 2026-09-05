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
/// ## Le ton, et ce qu'il exclut
///
/// La personnalité de la marque est ÉDUCATIVE (elle explique le pourquoi),
/// EXIGEANTE (elle compte sur la discipline plutôt que sur la motivation) et
/// BIENVEILLANTE (elle accompagne sans juger : essayer vaut mieux que
/// réussir parfaitement).
///
/// Quatre registres sont donc proscrits, et une première série les avait
/// tous adoptés sans qu'on y prenne garde :
///
/// - **la culpabilité** — « le jour où tu n'as pas envie compte double »,
///   « ne romps pas la chaîne » : punir une absence est le contraire
///   d'accompagner, et c'est ce qui fait abandonner ;
/// - **le culte de la douleur** — « écoute la douleur, elle a rarement
///   tort » : un conseil dangereux autant qu'une posture ;
/// - **le perfectionnisme** — « fais-le parfaitement » : la marque dit
///   exactement l'inverse ;
/// - **le jugement du corps** — « le poids ne ment pas ».
///
/// Une maxime Carlys apprend quelque chose, ou allège. Jamais elle ne fait
/// honte. `daily_quotes_test.dart` garde ces interdits par écrit.
///
/// Les entrées sont **entrelacées par valeur** (constance, maîtrise,
/// performance, discipline, équilibre, puis on recommence) : comme la
/// sélection avance d'un cran par jour, deux jours consécutifs ne servent
/// jamais la même valeur.
library;

import '../domain/entities/daily_quote.dart';

const List<DailyQuote> carlysQuotes = [
  // — Cycle 1
  DailyQuote(
    text: 'Reviens demain. C’est tout ce que la régularité demande.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Un mouvement compris vaut dix mouvements imités.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text:
        'Une répétition de plus qu’hier : la progression n’a pas besoin '
        'd’être spectaculaire.',
    value: CarlysValue.performance,
  ),
  DailyQuote(
    text:
        'La discipline te donne rendez-vous. La motivation, elle, ne '
        'prévient pas.',
    value: CarlysValue.discipline,
  ),
  DailyQuote(
    text: 'Le repos fait partie de l’entraînement, pas de son absence.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 2
  DailyQuote(
    text:
        'Une semaine ordinaire, répétée, vaut mieux qu’un mois parfait '
        'isolé.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Savoir quel muscle travaille change la façon dont il travaille.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text:
        'Ce qui te semblait lourd il y a six mois est ton échauffement '
        'd’aujourd’hui.',
    value: CarlysValue.performance,
  ),
  DailyQuote(
    text: 'Décide la veille : le matin, tu n’auras plus qu’à y aller.',
    value: CarlysValue.discipline,
  ),
  DailyQuote(
    text: 'Dors : c’est là que la séance d’aujourd’hui devient du muscle.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 3
  DailyQuote(
    text: 'Sauter une séance ne défait rien. La reprendre construit tout.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Cinq minutes de lecture t’entraînent mieux pendant des mois.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text:
        'Le muscle s’adapte à ce qu’on lui demande. Demande-lui un peu '
        'plus, régulièrement.',
    value: CarlysValue.performance,
  ),
  DailyQuote(
    text: 'Une séance écourtée mais faite tient l’engagement.',
    value: CarlysValue.discipline,
  ),
  DailyQuote(
    text: 'Un corps qui récupère est un corps qui progresse.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 4
  DailyQuote(
    text: 'Ton corps additionne les semaines, pas les exploits.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Le pourquoi d’un exercice te dit quand le remplacer.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text: 'Note tes charges : on ne progresse que sur ce qu’on mesure.',
    value: CarlysValue.performance,
  ),
  DailyQuote(
    text: 'Tu n’as pas besoin d’avoir envie. Tu as besoin d’avoir prévu.',
    value: CarlysValue.discipline,
  ),
  DailyQuote(
    text: 'Fatigué ? Allège la charge et garde le rendez-vous.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 5
  DailyQuote(
    text: 'La progression aime les rythmes tenables. Choisis le tien.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Les courbatures ne mesurent rien. Tes charges notées, si.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text:
        'Une répétition propre construit plus qu’une répétition '
        'arrachée.',
    value: CarlysValue.performance,
  ),
  DailyQuote(
    text:
        'Le plan existe pour les jours sans. Les jours avec se débrouillent '
        'seuls.',
    value: CarlysValue.discipline,
  ),
  DailyQuote(
    text: 'Adapter sa séance n’est pas renoncer. C’est durer.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 6
  DailyQuote(
    text:
        'Ce que tu peux tenir six mois vaut mieux que ce que tu tiens six '
        'jours.',
    value: CarlysValue.constance,
  ),
  DailyQuote(
    text: 'Comprendre son plan, c’est pouvoir l’adapter sans le casser.',
    value: CarlysValue.maitrise,
  ),
  DailyQuote(
    text:
        'La barre monte quand la semaine est complète, pas quand la séance '
        'est héroïque.',
    value: CarlysValue.performance,
  ),
  DailyQuote(
    text: 'Commence par l’échauffement. La suite se décide après.',
    value: CarlysValue.discipline,
  ),
  DailyQuote(
    text:
        'Une douleur qui s’installe n’est pas du courage. Va voir un '
        'professionnel de santé.',
    value: CarlysValue.equilibre,
  ),

  // — Cycle 7
  DailyQuote(
    text: 'Recommencer fait partie du plan : ce n’est pas repartir de zéro.',
    value: CarlysValue.constance,
  ),
  DailyQuote(text: 'Comprendre, puis charger.', value: CarlysValue.maitrise),
  DailyQuote(
    text: 'Ton record d’aujourd’hui sera ton échauffement de l’an prochain.',
    value: CarlysValue.performance,
  ),
  DailyQuote(
    text: 'Essayer compte déjà. Le reste vient tout seul.',
    value: CarlysValue.discipline,
  ),
  DailyQuote(
    text:
        'Bois, mange, dors : trois leviers que l’entraînement seul ne '
        'remplace pas.',
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
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(1970)).inDays;
}
