import 'package:flutter/material.dart';

/// LE LIBELLÉ D'UNE ACTION du design system : celui d'`AppButton` à icône,
/// d'`AppCtaButton` et d'`AppBrandButton`. Interne au design system (non
/// exporté par `design_system.dart`) : un écran passe par le bouton, jamais
/// par son libellé.
///
/// Une ligne à la taille d'origine ; DEUX dès que le texte système est
/// agrandi, et le bouton grandit avec elles, sur le modèle d'`AppListRow`.
/// Jamais coupé net : « Supprimer ce repas » finissait en « Supprimer ce »,
/// sans le moindre indice qu'il manquait un mot, et « Enregistrer la
/// modification » perdait sa fin dès le texte ×1,5 sur 360 points.
/// L'ellipse, en dernier recours, dit au moins qu'il en manque.
class AppActionLabel extends StatelessWidget {
  const AppActionLabel(this.label, {this.style, super.key});

  final String label;

  /// Le style du bouton qui le porte ; `null` laisse celui du bouton
  /// Material s'appliquer.
  final TextStyle? style;

  /// Une ligne, ou deux en texte agrandi.
  static int maxLines(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > 1 ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: maxLines(context),
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style,
    );
  }
}
