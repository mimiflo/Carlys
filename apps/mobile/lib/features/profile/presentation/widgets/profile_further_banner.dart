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
class ProfileFurtherBanner extends StatelessWidget {
  const ProfileFurtherBanner({required this.onTap, super.key});

  final VoidCallback onTap;

  /// Une hauteur MINIMALE, pas une hauteur : avec un texte système agrandi,
  /// les deux lignes du sous-titre en deviennent trois ou quatre, et une
  /// hauteur fixe les faisait déborder de la carte. La bannière grandit
  /// alors avec son texte, et l'illustration la couvre toujours.
  static const double _minHeight = 96;
  static const double _chevronSize = 24;

  @override
  Widget build(BuildContext context) {
    return ProfileHubCard(
      children: [
        Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minHeight),
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  const Positioned.fill(child: FurtherBannerIllustration()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
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
                              Text(
                                'Garde l’élan et atteins\n'
                                'de nouveaux objectifs.',
                                style: AppTypography.body.copyWith(
                                  color: AppColors.darkTextSecondary,
                                ),
                              ),
                            ],
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
