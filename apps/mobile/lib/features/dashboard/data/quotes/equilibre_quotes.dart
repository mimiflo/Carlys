/// Maximes de la valeur Équilibre.
///
/// « Tiens-tu dans la durée ? » Le fait mesuré est le RYTHME tenable.
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

const List<QuoteEntry> equilibreQuotes = [
  QuoteEntry('Le repos fait partie de l’entraînement, pas de son absence.'),
  QuoteEntry('Dors : c’est là que la séance d’aujourd’hui devient du muscle.'),
  QuoteEntry('Un corps qui récupère est un corps qui progresse.'),
  QuoteEntry('Fatigué ? Allège la charge et garde le rendez-vous.'),
  QuoteEntry('Adapter sa séance n’est pas renoncer. C’est durer.'),
  QuoteEntry(
    'Une douleur qui s’installe n’est pas du courage. Va voir un professionnel de santé.',
  ),
  QuoteEntry(
    'Bois, mange, dors : trois leviers que l’entraînement seul ne remplace pas.',
  ),
  QuoteEntry(
    'Un groupe musculaire met environ deux jours à se reconstruire. Alterne.',
  ),
  QuoteEntry(
    'Une nuit courte baisse ta force du jour. Ce n’est pas toi, c’est la fatigue.',
  ),
  QuoteEntry(
    'Le stress de ta semaine compte dans la charge totale. Ton corps ne trie pas.',
  ),
  QuoteEntry(
    'Marcher le lendemain aide plus à récupérer que l’immobilité complète.',
  ),
  QuoteEntry(
    'La déshydratation se sent à la barre avant de se sentir dans la gorge.',
  ),
  QuoteEntry(
    'Sept séances dans la semaine, ce n’est plus de l’entraînement. Repose-toi.',
    contexts: {QuoteContext.surcharge},
  ),
  QuoteEntry(
    'Récupérer n’est pas une pause dans le plan. C’est le plan.',
    contexts: {QuoteContext.recuperation, QuoteContext.surcharge},
  ),
  QuoteEntry(
    'Deux jours de repos réparent ce que sept jours d’affilée abîment.',
    contexts: {QuoteContext.surcharge},
  ),
  QuoteEntry(
    'Ce repos-là travaille pour toi. Laisse-le finir.',
    contexts: {QuoteContext.recuperation},
  ),
];
