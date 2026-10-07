import 'package:flutter/material.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../design_system/design_system.dart';

/// « Reprends ta séance » : la carte d'appel du hub quand une séance est en
/// cours (maquette d'octobre 2026). Y retourner est l'action la plus
/// probable de l'onglet — d'où le bouton plein, et non une simple ligne.
///
/// La photo d'haltères se pose en haut à droite et se FOND dans la carte par
/// la gauche et par le bas, sur l'alpha de l'image (même technique que
/// `SummitIllustration`) : aucune teinte nouvelle n'entre dans l'écran, et
/// le texte, borné à gauche, ne passe jamais dessus.
class ResumeWorkoutCard extends StatelessWidget {
  const ResumeWorkoutCard({required this.onResume, super.key});

  final VoidCallback onResume;

  /// WebP 356 × 285, tiré de la maquette fournie.
  static const String photoAsset = 'assets/illustrations/halteres.webp';

  /// Part de la largeur de la carte prise par la photo.
  static const double photoWidthFactor = 0.52;

  /// Part de la largeur laissée au texte : il s'arrête où la photo devient
  /// pleine.
  static const double textWidthFactor = 0.6;

  static const _logger = AppLogger('ResumeWorkoutCard');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                width: width * photoWidthFactor,
                bottom: AppSpacing.touchTarget + AppSpacing.md,
                child: _FadedPhoto(logger: _logger),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: width * textWidthFactor,
                      ),
                      child: const _Wording(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCtaButton(
                      label: 'Reprendre la séance',
                      icon: AppIcons.play,
                      onPressed: onResume,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Wording extends StatelessWidget {
  const _Wording();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIconBadge(
                icon: AppIcons.play,
                color: AppColors.accent,
                background: AppColors.accentBadgeBg,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'SÉANCE EN COURS',
                  style: AppTypography.labelMono.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            header: true,
            child: Text(
              'Reprends ta séance',
              style: AppTypography.title.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Reprendre là où tu t’es arrêté.',
            style: AppTypography.body.copyWith(color: AppColors.primaryLight),
          ),
        ],
      ),
    );
  }
}

class _FadedPhoto extends StatelessWidget {
  const _FadedPhoto({required this.logger});

  final AppLogger logger;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.neutral0, AppColors.neutral0Clear],
        stops: [0.7, 1],
      ).createShader(rect),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [AppColors.neutral0Clear, AppColors.neutral0],
          stops: [0, 0.35],
        ).createShader(rect),
        child: Image.asset(
          ResumeWorkoutCard.photoAsset,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          // Une photo absente laisse la carte nue — le texte et le bouton
          // suffisent — mais se DIT dans les journaux.
          errorBuilder: (context, error, stackTrace) {
            logger.warning(
              'Photo introuvable : ${ResumeWorkoutCard.photoAsset}',
              error: error,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
