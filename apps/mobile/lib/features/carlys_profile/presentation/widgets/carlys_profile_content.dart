import 'package:flutter/widgets.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/carlys_profile.dart';

/// Contenu ÉDITORIAL des quatre profils : titres, devises, descriptions et
/// publics — les textes de la spécification produit, mot pour mot.
///
/// Les illustrations sont attendues dans `assets/profiles/<slug>.webp`
/// (voir le README du dossier) ; tant qu'elles n'y sont pas, la carte pose
/// un repli de marque (dégradé + icône) — jamais un trou.
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

  /// La devise, à la première personne.
  final String quote;

  /// Description courte de la carte (celle de la maquette).
  final String tagline;

  /// « Pour : » — les publics du profil.
  final List<String> audience;

  final String assetPath;

  /// Repli tant que l'illustration n'est pas fournie.
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
        'Découvrir l’application.',
        'Découvrir le sport.',
        'Reprendre progressivement.',
        'Se maintenir en bonne santé.',
        'Développer sa culture sportive.',
      ],
      assetPath: 'assets/profiles/constructeur.webp',
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
      assetPath: 'assets/profiles/challenger.webp',
      icon: AppIcons.profileChallenger,
    ),
    CarlysProfile.athlete => const CarlysProfileContent(
      title: 'L’Athlète',
      quote: '« Je me prépare pour quelque chose. »',
      tagline:
          'Discipline et constance pour atteindre des '
          'objectifs ambitieux.',
      audience: [
        'Les personnes pratiquant régulièrement.',
        'Les personnes ayant un objectif précis.',
        'Les objectifs nécessitant discipline et constance.',
      ],
      assetPath: 'assets/profiles/athlete.webp',
      icon: AppIcons.profileAthlete,
    ),
    CarlysProfile.stratege => const CarlysProfileContent(
      title: 'Le Stratège',
      quote: '« Je veux comprendre avant d’agir. »',
      tagline:
          'Apprendre avant d’agir. Comprendre pour optimiser '
          'chaque décision.',
      audience: [
        'Les personnes qui veulent apprendre.',
        'Comprendre le fonctionnement du corps.',
        'Comprendre l’entraînement et la nutrition.',
        'Planifier avant d’agir.',
      ],
      assetPath: 'assets/profiles/stratege.webp',
      icon: AppIcons.profileStratege,
    ),
  };
}
