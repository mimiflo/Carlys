import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'further_banner_painter.dart';
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

  static const double _height = 96;
  static const double _chevronSize = 24;

  @override
  Widget build(BuildContext context) {
    return ProfileHubCard(
      children: [
        Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: _height,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ExcludeSemantics(
                      child: CustomPaint(painter: FurtherBannerPainter()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
