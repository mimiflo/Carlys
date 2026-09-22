/// Maximes de la valeur Performance.
///
/// « Progresses-tu ? » Le fait mesuré est la CHARGE et son volume.
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

const List<QuoteEntry> performanceQuotes = [
  QuoteEntry(
    'Une répétition de plus qu’hier : la progression n’a pas besoin d’être spectaculaire.',
  ),
  QuoteEntry(
    'Ce qui te semblait lourd il y a six mois est ton échauffement d’aujourd’hui.',
  ),
  QuoteEntry(
    'Le muscle s’adapte à ce qu’on lui demande. Demande-lui un peu plus, régulièrement.',
  ),
  QuoteEntry('Note tes charges : on ne progresse que sur ce qu’on mesure.'),
  QuoteEntry(
    'Une répétition propre construit plus qu’une répétition arrachée.',
  ),
  QuoteEntry(
    'La barre monte quand la semaine est complète, pas quand la séance est héroïque.',
  ),
  QuoteEntry(
    'Ton record d’aujourd’hui sera ton échauffement de l’an prochain.',
  ),
  QuoteEntry(
    'La charge n’est pas le seul curseur : répétitions, séries, amplitude, tempo.',
  ),
  QuoteEntry(
    'Garde deux répétitions en réserve : tu construis presque autant et récupères mieux.',
  ),
  QuoteEntry(
    'Une semaine plus légère tous les deux mois relance la progression.',
  ),
  QuoteEntry(
    'La progression ralentit avec les mois. C’est le signe que tu n’es plus débutant.',
  ),
  QuoteEntry(
    'Compare-toi à tes chiffres d’il y a trois mois : c’est ce qui t’apprend le plus.',
  ),
  QuoteEntry(
    'Un record ne se refait pas chaque semaine. Celui-ci, savoure-le.',
    contexts: {QuoteContext.recordBattu},
  ),
  QuoteEntry(
    'Objectif atteint. Le suivant attendra demain.',
    contexts: {QuoteContext.objectifAtteint},
  ),
  QuoteEntry(
    'Une semaine plus légère n’est pas un recul : c’est ce qui relance la suite.',
    contexts: {QuoteContext.plateau},
  ),
  QuoteEntry(
    'Tu viens de déplacer ta limite. Elle ne reviendra pas où elle était.',
    contexts: {QuoteContext.recordBattu},
  ),
];
