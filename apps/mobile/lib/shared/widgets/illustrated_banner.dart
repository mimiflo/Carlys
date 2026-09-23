import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import 'summit_illustration.dart';

/// Une bannière de motivation : un titre, une phrase, et le sommet au fanion
/// fondu dans la carte — « Toujours plus loin » au bas du profil, « Petits
/// efforts, grands résultats » au bas de la ligue.
///
/// Née dans le profil, rangée ici dès qu'une deuxième fonctionnalité en a eu
/// besoin : deux copies d'un même décor finissent toujours par différer, et
/// la Communauté n'importe aucune autre fonctionnalité.
///
/// Trois couches, dans cet ordre :
///  1. l'illustration, fondue dans la carte ;
///  2. un `Material` TRANSPARENT qui porte l'encre de l'appui. Posée sur la
///     carte, l'encre passait SOUS l'image, et la moitié droite de la porte
///     — chevron compris — ne réagissait plus au doigt ;
///  3. le texte et, si la bannière est une porte, le chevron.
class IllustratedBanner extends StatelessWidget {
  const IllustratedBanner({
    required this.title,
    required this.body,
    this.titleAccent,
    this.onTap,
    super.key,
  });

  final String title;

  /// Une seconde ligne de titre, en violet clair (« grands résultats. »).
  final String? titleAccent;
  final String body;

  /// Nul : la bannière n'est qu'un mot d'encouragement — ni chevron, ni
  /// rôle de bouton. Un chevron qui ne mène nulle part serait une promesse.
  final VoidCallback? onTap;

  /// Marge entre la fin du texte et l'endroit où l'image devient pleine :
  /// le bord de la lune y commence, et un glyphe qui le toucherait perdrait
  /// son contraste. Huit points et pas seize : à seize, le titre passait à
  /// la ligne sur un téléphone de 360 points à la taille de texte normale.
  static const double textClearance = AppSpacing.xs;

  static const double _chevronSize = 24;

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        // Le texte s'arrête AVANT la partie pleine de l'image, à toute taille
        // de texte : agrandi, il passe à la ligne au lieu de glisser sur la
        // lune. À la taille normale, il tient dans la borne.
        final textMaxWidth =
            SummitIllustration.opaqueFromFor(constraints.maxWidth) -
            textClearance -
            AppSpacing.md;

        final row = ConstrainedBox(
          // Une hauteur MINIMALE, pas une hauteur : un texte système agrandi
          // fait grandir la bannière au lieu de déborder de la carte.
          constraints: const BoxConstraints(
            minHeight: SummitIllustration.referenceHeight,
          ),
          child: Padding(
            // La gouttière des lignes du profil : les chevrons s'alignent
            // tous sur la même verticale.
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: textMaxWidth),
                      child: _Wording(
                        title: title,
                        titleAccent: titleAccent,
                        body: body,
                      ),
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    AppIcons.chevronRight,
                    size: _chevronSize,
                    color: AppColors.darkTextSecondary,
                  ),
              ],
            ),
          ),
        );

        return Stack(
          children: [
            const Positioned.fill(child: SummitIllustration()),
            if (onTap == null)
              row
            else
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, child: row),
              ),
          ],
        );
      },
    );

    return Material(
      color: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      // Son propre nœud : fusionnée dans la page, la bannière y mêlait son
      // texte — et, touchable, étendait son geste à tout ce qui l'entoure.
      child: Semantics(container: true, button: onTap != null, child: content),
    );
  }
}

class _Wording extends StatelessWidget {
  const _Wording({
    required this.title,
    required this.titleAccent,
    required this.body,
  });

  final String title;
  final String? titleAccent;
  final String body;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.resized(
      AppTypography.title,
      19,
    ).copyWith(color: AppColors.darkTextPrimary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (titleAccent != null)
          Text(
            titleAccent!,
            style: titleStyle.copyWith(color: AppColors.primaryLight),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}
