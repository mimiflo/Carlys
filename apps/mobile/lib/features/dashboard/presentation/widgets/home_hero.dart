import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';
import '../../domain/entities/daily_quote.dart';
import 'daily_quote_card.dart';
import 'home_header.dart';

/// Zone haute de l'accueil : **le cœur qui bat** à droite, la citation du
/// jour à sa gauche, sur toute la hauteur de la zone.
///
/// Le cœur est la signature de l'application : rien ne se pose sur sa masse.
/// La citation occupe la colonne restée vide à gauche et descend jusqu'au
/// pied de la zone, là où commence la série de constance — d'où sa forme
/// haute plutôt que compacte.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.displayName,
    required this.subtitle,
    required this.quote,
    super.key,
  });

  final String? displayName;
  final String subtitle;
  final DailyQuote quote;

  /// Géométrie de la scène, inchangée depuis l'origine : 330 posée à 64 du
  /// haut, débordant de 126 à droite.
  static const double _sceneSize = 330;
  static const double _sceneTop = 64;
  static const double _sceneRight = -126;

  /// Retrait haut du contenu : aucun texte sous la Dynamic Island.
  static const double _topInset = 88;

  /// Fondu vertical de la scène (transparent → plein → transparent).
  static const List<double> _sceneFade = [0.0, 0.16, 0.46, 0.76];

  /// Hauteur à laquelle le fondu a ÉTEINT la scène (dernier point de
  /// [_sceneFade]) : plancher sous lequel la série peut vivre sans recouvrir
  /// le cœur.
  static const double _sceneBottom = _sceneTop + _sceneSize * 0.76;

  /// Hauteur réservée : la scène éteinte plus une gouttière. Une citation
  /// plus longue que la moyenne fait grandir la zone au-delà.
  static const double _minHeight = _sceneBottom + AppSpacing.gapRow;

  /// Part de la largeur laissée à la citation. Le cœur entame l'écran à
  /// `largeur − 330 + 126` ; on s'arrête juste avant sa masse, sans jamais
  /// mordre sur son centre.
  static const int _quoteFlex = 55;
  static const int _sceneFlex = 45;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    // Ce qui reste à la citation entre l'en-tête et le pied de la zone. Tout
    // est connu — l'encoche, la gouttière, la hauteur FIXE de l'en-tête —
    // donc la carte descend exactement jusqu'à la série, quel que soit
    // l'appareil, et la zone haute garde la même hauteur tous les jours.
    // Retrait haut FERME : la maquette pose le contenu à 88 du bord, quelle
    // que soit l'encoche. Sur un appareil à grande encoche, c'est elle qui
    // commande — jamais moins que la marge système.
    final top = math.max(_topInset, topInset + AppSpacing.xs);
    final quoteHeight = math.max(
      0.0,
      _minHeight -
          (top + HomeHeader.height + AppSpacing.gapRow) -
          AppSpacing.gapRow,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: _sceneTop,
            right: _sceneRight,
            child: AppSceneContainer(
              size: _sceneSize,
              opacity: 0.9,
              verticalFadeStops: _sceneFade,
              child: HeartScene(),
            ),
          ),
          // Lisibilité, dans l'ordre de la maquette (la couche listée en
          // premier en CSS est la plus haute) : extinction verticale, puis
          // assombrissement latéral, puis le halo violet PAR-DESSUS.
          const Positioned.fill(child: AppSceneScrim.vertical()),
          const Positioned.fill(child: AppSceneScrim.lateral()),
          const Positioned.fill(
            child: AppSceneGlow(
              center: Alignment(0.48, -0.16),
              radius: 0.71,
              alpha: 0.32,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: top,
              left: AppSpacing.gutter,
              right: AppSpacing.gutter,
              bottom: AppSpacing.gapRow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                HomeHeader(displayName: displayName, subtitle: subtitle),
                const SizedBox(height: AppSpacing.gapRow),
                Row(
                  // `stretch` forcerait une hauteur infinie : dans une liste,
                  // la colonne n'a pas de plafond vertical. C'est la
                  // contrainte posée sur la carte qui lui donne sa hauteur.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: _quoteFlex,
                      // Hauteur FERME, pas un plancher : la citation choisit
                      // son corps pour remplir exactement ce cadre, donc rien
                      // ne peut ni déborder ni sonner creux.
                      child: SizedBox(
                        height: quoteHeight,
                        child: DailyQuoteCard(quote: quote),
                      ),
                    ),
                    // Colonne laissée au cœur : rien ne s'y pose.
                    const Expanded(flex: _sceneFlex, child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
