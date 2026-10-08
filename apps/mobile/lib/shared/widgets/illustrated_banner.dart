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
    this.body,
    this.titleAccent,
    this.onTap,
    this.summitShift = 0,
    this.leading,
    super.key,
  });

  final String title;

  /// Une seconde ligne de titre, en violet clair (« grands résultats. »).
  final String? titleAccent;

  /// Nul : la bannière n'est qu'un titre (« Un effort aujourd'hui. / Un pas
  /// de plus demain. » du hub Training).
  final String? body;

  /// Nul : la bannière n'est qu'un mot d'encouragement — ni chevron, ni
  /// rôle de bouton. Un chevron qui ne mène nulle part serait une promesse.
  final VoidCallback? onTap;

  /// Glisse le sommet vers la droite (rogné par la carte) et rend autant de
  /// largeur au texte : un titre de deux lignes sans corps (« Un effort
  /// aujourd'hui. ») tient alors sur deux lignes, et non quatre.
  final double summitShift;

  /// Un emblème devant le texte (la médaille de « Mon parcours »), logé dans
  /// un carré de [leadingSize] : le texte sait ainsi la largeur qu'il cède.
  /// Il s'efface quand le texte agrandi n'aurait plus la place d'un mot.
  final Widget? leading;

  static const double leadingSize = 44;

  /// Marge entre la fin du texte et l'endroit où l'image devient pleine :
  /// le bord de la lune y commence, et un glyphe qui le toucherait perdrait
  /// son contraste. Huit points et pas seize : à seize, le titre passait à
  /// la ligne sur un téléphone de 360 points à la taille de texte normale.
  static const double textClearance = AppSpacing.xs;

  static const double _chevronSize = 24;

  /// La largeur de texte, à la taille normale, sous laquelle l'emblème
  /// s'efface (voir [leading]).
  static const double _leadingTextMinWidth = 90;

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        // Le texte s'arrête AVANT la partie pleine de l'image, à toute taille
        // de texte : agrandi, il passe à la ligne au lieu de glisser sur la
        // lune. À la taille normale, il tient dans la borne.
        final textRoom =
            SummitIllustration.opaqueFromFor(constraints.maxWidth) +
            summitShift -
            textClearance -
            AppSpacing.md;
        // L'emblème cède sa place quand le texte, agrandi, n'aurait plus
        // la largeur d'un mot : « récompenses » se coupait en son milieu
        // sur 320 points au texte ×2.
        final leading =
            textRoom - leadingSize - AppSpacing.sm >=
                MediaQuery.textScalerOf(context).scale(_leadingTextMinWidth)
            ? this.leading
            : null;
        final textMaxWidth =
            textRoom - (leading == null ? 0 : leadingSize + AppSpacing.sm);

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
                if (leading case final leading?) ...[
                  SizedBox.square(dimension: leadingSize, child: leading),
                  const SizedBox(width: AppSpacing.sm),
                ],
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
            Positioned(
              top: 0,
              bottom: 0,
              left: summitShift,
              right: -summitShift,
              child: const SummitIllustration(),
            ),
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
  final String? body;

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
        if (body case final body?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
