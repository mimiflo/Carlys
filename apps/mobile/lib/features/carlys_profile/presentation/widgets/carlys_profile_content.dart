import 'package:flutter/widgets.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/carlys_profile.dart';

/// Contenu ÉDITORIAL des quatre profils : titres, devises, descriptions et
/// publics — les textes de la spécification produit, mot pour mot.
///
/// Les médaillons vivent dans `assets/profiles/medaillon_<slug>.webp` (voir
/// le README du dossier) ; un fichier manquant laisse un disque de marque et
/// l'icône du profil — jamais un trou.
class CarlysProfileContent {
  const CarlysProfileContent({
    required this.title,
    required this.quote,
    required this.tagline,
    required this.audience,
    required this.assetPath,
    required this.icon,
  });

  /// « Le Constructeur » — rendu en capitales par la carte.
  final String title;

  /// « Constructeur », « Athlète » : le titre sans son article, là où il
  /// suit déjà « Ton profil : ».
  String get shortTitle => title.replaceFirst(RegExp('^(Le |La |L’)'), '');

  /// La devise, à la première personne.
  final String quote;

  /// Description courte de la carte (celle de la maquette).
  final String tagline;

  /// « Pour toi si… » — ce que le profil sert.
  final List<String> audience;

  final String assetPath;

  /// Repli si le médaillon manque.
  final IconData icon;
}

CarlysProfileContent carlysProfileContentOf(CarlysProfile profile) {
  return switch (profile) {
    CarlysProfile.constructeur => const CarlysProfileContent(
      title: 'Le Constructeur',
      quote: '« Je commence à construire. »',
      tagline:
          'Découvrir, apprendre, construire les bases. '
          'Santé et culture avant tout.',
      audience: [
        'Découvrir l’application et le sport.',
        'Reprendre progressivement.',
        'Se maintenir en bonne santé.',
        'Développer sa culture sportive.',
      ],
      assetPath: 'assets/profiles/medaillon_constructeur.webp',
      icon: AppIcons.profileConstructeur,
    ),
    CarlysProfile.challenger => const CarlysProfileContent(
      title: 'Le Challenger',
      quote: '« Je veux aller plus loin. »',
      tagline:
          'Sortir de sa zone de confort et se dépasser '
          'pour progresser.',
      audience: [
        'Se dépasser.',
        'Sortir de sa zone de confort.',
        'Progresser physiquement.',
        'Progresser intellectuellement.',
      ],
      assetPath: 'assets/profiles/medaillon_challenger.webp',
      icon: AppIcons.profileChallenger,
    ),
    CarlysProfile.athlete => const CarlysProfileContent(
      title: 'L’Athlète',
      quote: '« Je me prépare pour quelque chose. »',
      tagline:
          'Discipline et constance pour atteindre des '
          'objectifs ambitieux.',
      audience: [
        'Pratiquer régulièrement.',
        'Poursuivre un objectif précis.',
        'Construire sa discipline et sa constance.',
      ],
      assetPath: 'assets/profiles/medaillon_athlete.webp',
      icon: AppIcons.profileAthlete,
    ),
    CarlysProfile.stratege => const CarlysProfileContent(
      title: 'Le Stratège',
      quote: '« Je veux comprendre avant d’agir. »',
      tagline:
          'Apprendre avant d’agir. Comprendre pour optimiser '
          'chaque décision.',
      audience: [
        'Apprendre et approfondir ses connaissances.',
        'Comprendre le fonctionnement du corps.',
        'Comprendre l’entraînement et la nutrition.',
        'Planifier avant d’agir.',
      ],
      assetPath: 'assets/profiles/medaillon_stratege.webp',
      icon: AppIcons.profileStratege,
    ),
  };
}
