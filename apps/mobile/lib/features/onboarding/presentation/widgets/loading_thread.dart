import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Fil de lumière : un filet que le dégradé de marque parcourt, sa lueur
/// avec lui.
///
/// Pas un indicateur circulaire : celui-ci tourne sans fin et dit « ça
/// travaille » ; un fil qui se remplit dit « ça arrive », ce qui est la
/// vérité ici, la durée étant connue.
///
/// Pas de pastille en tête non plus : elle donnait un curseur de réglage,
/// gros et matériel, au milieu d'une page qui ne vit que de lumière. Ce qui
/// avance est une lueur, pas une pièce.
///
/// Le dégradé est peint sur TOUTE la longueur puis dévoilé, au lieu d'être
/// étiré à la largeur remplie : les couleurs restent à leur place et c'est la
/// lumière qui avance, pas la palette qui se comprime.
class LoadingThread extends StatelessWidget {
  const LoadingThread({required this.progress, super.key});

  final Animation<double> progress;

  /// La part de la scène pendant laquelle le fil se remplit : il court sur
  /// presque toute sa durée, moins la dernière respiration — il doit être
  /// PLEIN avant que l'écran ne s'efface, sinon il donne l'impression d'un
  /// chargement interrompu.
  static const Interval interval = Interval(0.12, 0.9, curve: Curves.easeInOut);

  static const double _width = 116;
  static const double _rail = 2;

  /// La boîte respire au-delà du filet : la lueur a besoin de place, sinon
  /// elle serait coupée net en haut et en bas.
  static const double _box = 16;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement de Carlys',
      child: ExcludeSemantics(
        child: SizedBox(
          width: _width,
          height: _box,
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final filled = interval.transform(progress.value.clamp(0.0, 1.0));
              return Stack(
                alignment: Alignment.center,
                children: [
                  const _Rail(),
                  _Glow(filled: filled),
                  _Fill(filled: filled),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Le filet vide : à peine là, mais présent — sans lui, la barre n'aurait
/// pas de longueur annoncée et l'attente paraîtrait sans fin.
class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LoadingThread._rail,
      decoration: BoxDecoration(
        color: AppColors.darkBorderStrong,
        borderRadius: BorderRadius.circular(LoadingThread._rail),
      ),
    );
  }
}

/// La lueur sous la part parcourue.
///
/// Posée AVANT le dégradé et hors du découpage : une ombre portée peinte à
/// l'intérieur du clip serait rognée avec lui, et ne déborderait donc jamais
/// — or c'est tout ce qu'on lui demande.
class _Glow extends StatelessWidget {
  const _Glow({required this.filled});

  final double filled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: (LoadingThread._width * filled).clamp(1.0, double.infinity),
        height: LoadingThread._rail,
        child: DecoratedBox(
          // Aucune couleur de fond : seules les ombres se peignent, et le
          // dégradé passera par-dessus.
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryFlash.withValues(alpha: 0.40),
                blurRadius: 10,
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.20),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La part parcourue, découpée dans un dégradé peint sur toute la longueur.
class _Fill extends StatelessWidget {
  const _Fill({required this.filled});

  final double filled;

  @override
  Widget build(BuildContext context) {
    // L'`Align` EXTÉRIEUR est indispensable : le découpage ne fait que la
    // largeur parcourue, et la pile, qui centre ses enfants, le poserait au
    // milieu du filet. La barre se remplissait alors depuis son centre.
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LoadingThread._rail),
        child: Align(
          alignment: Alignment.centerLeft,
          // Cet `Align`-ci se dimensionne à une FRACTION de son enfant, et
          // c'est ce découpage qui dévoile le dégradé. Jamais tout à fait
          // zéro : une largeur nulle escamoterait la boîte.
          widthFactor: filled.clamp(0.001, 1),
          child: Container(
            width: LoadingThread._width,
            height: LoadingThread._rail,
            decoration: const BoxDecoration(gradient: AppColors.signature),
          ),
        ),
      ),
    );
  }
}
