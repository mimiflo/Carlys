/// Maximes de la valeur Discipline.
///
/// « Tiens-tu tes rendez-vous ? » Le fait mesuré est l'ENGAGEMENT.
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

const List<QuoteEntry> disciplineQuotes = [
  QuoteEntry(
    'La discipline te donne rendez-vous. La motivation, elle, ne prévient pas.',
  ),
  QuoteEntry('Décide la veille : le matin, tu n’auras plus qu’à y aller.'),
  QuoteEntry('Une séance écourtée mais faite tient l’engagement.'),
  QuoteEntry('Tu n’as pas besoin d’avoir envie. Tu as besoin d’avoir prévu.'),
  QuoteEntry(
    'Le plan existe pour les jours sans. Les jours avec se débrouillent seuls.',
  ),
  QuoteEntry('Commence par l’échauffement. La suite se décide après.'),
  QuoteEntry('Essayer compte déjà. Le reste vient tout seul.'),
  QuoteEntry(
    'Prévois la version courte de chaque séance : les jours chargés la prendront.',
  ),
  QuoteEntry(
    'Choisis d’avance ce que tu fais si la machine est prise : tu auras un plan B.',
  ),
  QuoteEntry(
    'Quand le plan tombe à l’eau, garde l’horaire : c’est lui qui tient l’habitude.',
  ),
  QuoteEntry(
    'Un créneau noté au calendrier se défend mieux qu’une bonne intention.',
  ),
  QuoteEntry(
    'Une séance abandonnée en cours se reprend le lendemain, pas la semaine d’après.',
    contexts: {QuoteContext.seanceAbandonnee},
  ),
  QuoteEntry(
    'Carlys compte les séances que tu termines, pas celles que tu commences.',
  ),
  QuoteEntry(
    'Commence par l’échauffement : la suite se décide après.',
    contexts: {QuoteContext.pauseEnCours, QuoteContext.semaineCreuse},
  ),
  QuoteEntry(
    'Ce que tu as commencé compte déjà. Termine la prochaine.',
    contexts: {QuoteContext.seanceAbandonnee},
  ),
  QuoteEntry(
    'Le premier rendez-vous est le plus facile à tenir. Prends le second.',
    contexts: {QuoteContext.premiereSeance},
  ),
  QuoteEntry(
    'Tenir une série, c’est décider la veille, pas le matin.',
    contexts: {QuoteContext.serieEnCours},
  ),
];
