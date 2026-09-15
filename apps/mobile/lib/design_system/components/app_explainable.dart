import 'package:flutter/material.dart';

/// Rend une donnée AFFICHÉE tapable, pour qu'elle ouvre elle-même son POURQUOI.
///
/// C'est la seconde moitié de la porte d'explication, et la plus fréquente.
/// [AppExplainButton] convient quand le glyphe EST le bouton — à côté d'un
/// libellé de champ, par exemple. Mais dès que la donnée occupe déjà une
/// surface plus grande que la cible tactile minimale — une tuile de stat, une
/// ligne de macro, un chiffre de hero — poser dessus un bouton de 48 points
/// recouvre la valeur et crée DEUX cibles concurrentes pour une seule
/// intention : le doigt ne sait plus où viser et le lecteur d'écran annonce
/// deux fois la même chose.
///
/// Ici, c'est la donnée entière qui répond. Le glyphe d'information reste
/// visible à côté du libellé, mais comme ORNEMENT : il dit qu'il y a quelque
/// chose à ouvrir, il ne le porte pas.
///
/// Le composant ne connaît aucun contenu : il appelle [onExplain]. Ce qui
/// s'ouvre est du domaine, pas du design system.
class AppExplainable extends StatelessWidget {
  const AppExplainable({
    required this.child,
    required this.onExplain,
    required this.enonce,
    this.padding = EdgeInsets.zero,
    this.surface,
    this.borderRadius,
    super.key,
  });

  final Widget child;

  /// Ouvre l'explication de la donnée enveloppée.
  final VoidCallback onExplain;

  /// Ce que le lecteur d'écran annonce, sans le mot « Explication » que ce
  /// composant ajoute : « IMC : 27,3 », « Protéines : 148 g par jour ».
  ///
  /// La sémantique des enfants est EXCLUE : un chiffre géant, son libellé et
  /// son glyphe forment une seule donnée, pas trois annonces.
  final String enonce;

  /// Rembourrage intérieur — c'est lui qui porte une donnée courte au-dessus
  /// de la cible tactile minimale quand son contenu ne suffit pas.
  final EdgeInsetsGeometry padding;

  /// Fond peint par le `Material` sous-jacent. Laissé nul, la donnée reste
  /// transparente et l'onde se dessine sur ce qui est derrière.
  final Color? surface;

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$enonce. Explication',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: surface ?? Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onExplain,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
