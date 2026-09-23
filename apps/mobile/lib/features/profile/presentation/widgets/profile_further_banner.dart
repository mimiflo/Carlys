import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'further_banner_illustration.dart';
import 'profile_hub_tile.dart';

/// « Toujours plus loin » : la porte vers un nouveau programme, en bas du
/// profil, quand tout ce qui précède a été regardé.
///
/// Elle mène à la préparation d'un programme — objectif, expérience,
/// rythme, matériel — parce que c'est la seule façon concrète, dans
/// l'application, de se fixer un nouvel objectif.
///
/// Trois couches, dans cet ordre :
///  1. l'illustration, fondue dans la carte ;
///  2. un `Material` TRANSPARENT qui porte l'encre de l'appui. Posée sur la
///     carte, l'encre passait SOUS l'image, et la moitié droite de la porte
///     — chevron compris — ne réagissait plus au doigt ;
///  3. le texte et le chevron.
class ProfileFurtherBanner extends StatelessWidget {
  const ProfileFurtherBanner({required this.onTap, super.key});

  final VoidCallback onTap;

  /// Marge entre la fin du texte et l'endroit où l'image devient pleine :
  /// le bord de la lune y commence, et un glyphe qui le toucherait perdrait
  /// son contraste. Huit points et pas seize : à seize, le titre passait à
  /// la ligne sur un téléphone de 360 points à la taille de texte normale.
  static const double textClearance = AppSpacing.xs;

  static const double _chevronSize = 24;

  @override
  Widget build(BuildContext context) {
    return ProfileHubCard(
      children: [
        Semantics(
          button: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Le texte s'arrête AVANT la partie pleine de l'image, à toute
              // taille de texte : agrandi, il passe à la ligne au lieu de
              // glisser sur la lune. À la taille normale, il tient dans la
              // borne et rien ne change.
              final textMaxWidth =
                  FurtherBannerIllustration.opaqueFromFor(
                    constraints.maxWidth,
                  ) -
                  textClearance -
                  AppSpacing.md;

              return Stack(
                children: [
                  const Positioned.fill(child: FurtherBannerIllustration()),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: onTap,
                      child: ConstrainedBox(
                        // Une hauteur MINIMALE, pas une hauteur : un texte
                        // système agrandi fait grandir la bannière au lieu
                        // de déborder de la carte.
                        constraints: const BoxConstraints(
                          minHeight: FurtherBannerIllustration.referenceHeight,
                        ),
                        child: Padding(
                          // La même gouttière que les lignes du profil : les
                          // chevrons s'alignent tous sur la même verticale.
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
                                    constraints: BoxConstraints(
                                      maxWidth: textMaxWidth,
                                    ),
                                    child: const _Wording(),
                                  ),
                                ),
                              ),
                              const Icon(
                                AppIcons.chevronRight,
                                size: _chevronSize,
                                color: AppColors.darkTextSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Wording extends StatelessWidget {
  const _Wording();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toujours plus loin',
          style: AppTypography.resized(
            AppTypography.title,
            19,
          ).copyWith(color: AppColors.darkTextPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Aucun retour à la ligne forcé : il laissait « atteins » seul sur
        // sa ligne dès que le texte grandissait. L'espace INSÉCABLE soude
        // « de nouveaux » : la phrase se coupe d'elle-même devant « de »,
        // comme sur la maquette, et jamais un « de » ne finit une ligne.
        Text(
          'Garde l’élan et atteins de\u00A0nouveaux objectifs.',
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}
