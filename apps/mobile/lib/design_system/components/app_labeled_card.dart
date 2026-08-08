import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import 'app_section_label.dart';

/// Carte à label : un label mono MAJUSCULES en haut à gauche, un ornement
/// facultatif à droite, le contenu dessous.
///
/// C'est la brique de composition de l'accueil : chaque bloc — citation,
/// constance, résumé — est une carte de cette forme, ce qui donne au tableau
/// de bord son rythme régulier.
class AppLabeledCard extends StatelessWidget {
  const AppLabeledCard({
    required this.label,
    required this.child,
    this.trailing,
    this.labelColor = AppColors.darkTextTertiary,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.expandChild = false,
    this.semanticLabel,
    super.key,
  });

  /// Ex. « CITATION DU JOUR », « SÉRIE DE CONSTANCE ».
  final String label;

  /// Ornement de droite, aligné sur le label (icône, glyphe, valeur).
  final Widget? trailing;
  final Color labelColor;
  final EdgeInsetsGeometry padding;

  /// Donne au contenu TOUTE la hauteur restante sous le label.
  ///
  /// À n'activer que si la carte reçoit elle-même une hauteur bornée : sans
  /// plafond vertical, l'étirement n'a rien à quoi se mesurer et la mise en
  /// page échoue. En contrepartie le contenu peut s'adapter à la place reçue —
  /// c'est ce dont [AppFittedText] a besoin.
  final bool expandChild;
  final Widget child;

  /// Remplace la lecture d'écran du contenu quand celui-ci est décoratif.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: AppSectionLabel(label, color: labelColor)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );

    if (semanticLabel == null) {
      return card;
    }
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: card),
    );
  }
}
