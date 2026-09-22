/// Maximes de la valeur Constance.
///
/// « Reviens-tu ? » Le fait mesuré est la RÉGULARITÉ des séances.
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

const List<QuoteEntry> constanceQuotes = [
  QuoteEntry('Reviens demain. C’est tout ce que la régularité demande.'),
  QuoteEntry(
    'Une semaine ordinaire, répétée, vaut mieux qu’un mois parfait isolé.',
  ),
  QuoteEntry(
    'Deux séances par semaine, tenues un an, battent six séances tenues un mois.',
  ),
  QuoteEntry(
    'La régularité ne se voit pas d’un jour à l’autre. Elle se voit d’un trimestre à l’autre.',
  ),
  QuoteEntry(
    'Sauter une séance ne défait rien. La reprendre construit tout.',
    contexts: {QuoteContext.pauseEnCours, QuoteContext.semaineCreuse},
  ),
  QuoteEntry('Ton corps additionne les semaines, pas les exploits.'),
  QuoteEntry('La progression aime les rythmes tenables. Choisis le tien.'),
  QuoteEntry(
    'Ce que tu peux tenir six mois vaut mieux que ce que tu tiens six jours.',
  ),
  QuoteEntry(
    'Recommencer fait partie du plan : ce n’est pas repartir de zéro.',
  ),
  QuoteEntry(
    'Le plus dur n’est pas la première séance, c’est la troisième semaine.',
  ),
  QuoteEntry(
    'Après une pause, reprends plus léger : la technique revient avant la force.',
    contexts: {QuoteContext.retourApresPause},
  ),
  QuoteEntry(
    'En voyage, dix minutes au poids du corps suffisent à garder l’habitude.',
  ),
  QuoteEntry(
    'Le corps ne s’adapte qu’à ce qui revient : c’est tout ce que la régularité sert.',
  ),
  QuoteEntry(
    'Huit semaines : c’est la fenêtre que Carlys regarde. Une semaine creuse s’y dilue.',
  ),
  QuoteEntry(
    'Recommencer fait partie du plan : ce n’est pas repartir de zéro.',
    contexts: {
      QuoteContext.retourApresPause,
      QuoteContext.pauseEnCours,
      QuoteContext.seanceAbandonnee,
    },
  ),
  QuoteEntry(
    'Te voilà. C’est la seule chose que la régularité demandait.',
    contexts: {QuoteContext.retourApresPause},
  ),
  QuoteEntry(
    'Une première séance ne prouve rien. Elle ouvre tout.',
    contexts: {QuoteContext.premiereSeance},
  ),
  QuoteEntry(
    'La semaine n’est pas finie. Une séance suffit à la sauver.',
    contexts: {QuoteContext.semaineCreuse},
  ),
  QuoteEntry(
    'Cette série tient parce que tu reviens, pas parce que tu forces.',
    contexts: {QuoteContext.serieEnCours},
  ),
];
