/// Maximes de la valeur Maîtrise.
///
/// « Comprends-tu ce que tu fais ? » Le fait mesuré est l'APPRENTISSAGE.
///
/// Les maximes ne sont QUE du texte et des étiquettes ici : la valeur leur
/// est attachée à la recomposition, dans `daily_quotes.dart`. Une liste par
/// valeur rend l'entrelacement structurel au lieu de le confier à la
/// vigilance de qui ajoute une entrée.
///
/// Une maxime SANS contexte tourne au calendrier, et les cinq listes doivent
/// en garder le MÊME nombre : `entrelacer` refuse de composer autrement, et
/// c'est ce qui garantit que deux jours consécutifs ne servent jamais la
/// même valeur. Une maxime ÉTIQUETÉE, elle, ne sort que quand son fait est
/// vrai — elle s'ajoute librement, sans contrainte d'équilibre.
library;

import '../../domain/entities/daily_quote.dart';

const List<QuoteEntry> maitriseQuotes = [
  QuoteEntry('Un mouvement compris vaut dix mouvements imités.'),
  QuoteEntry('Savoir quel muscle travaille change la façon dont il travaille.'),
  QuoteEntry('Cinq minutes de lecture t’entraînent mieux pendant des mois.'),
  QuoteEntry('Le pourquoi d’un exercice te dit quand le remplacer.'),
  QuoteEntry('Les courbatures ne mesurent rien. Tes charges notées, si.'),
  QuoteEntry('Comprendre son plan, c’est pouvoir l’adapter sans le casser.'),
  QuoteEntry('Comprendre, puis charger.'),
  QuoteEntry(
    'Apprends un mouvement à vide : la charge ne corrige jamais une technique.',
  ),
  QuoteEntry(
    'Le temps de repos est un réglage, pas une pause. Note-le comme une charge.',
  ),
  QuoteEntry(
    'Compte trois secondes à la descente : elle compte autant que la montée.',
  ),
  QuoteEntry('Gagne de l’amplitude avant d’ajouter des kilos à la barre.'),
  QuoteEntry(
    'Quand tu le peux, filme une série : tu verras ce que tu ne sens pas.',
  ),
  QuoteEntry(
    'Il te reste des mouvements à comprendre. C’est la meilleure nouvelle du jour.',
    contexts: {QuoteContext.apprentissage},
  ),
  QuoteEntry(
    'Quand la charge stagne, c’est souvent la technique qui a quelque chose à dire.',
    contexts: {QuoteContext.plateau},
  ),
  QuoteEntry(
    'Apprends le mouvement avant de le charger : tu gagneras des mois.',
    contexts: {QuoteContext.premiereSeance, QuoteContext.apprentissage},
  ),
];
