import 'package:flutter/material.dart';

import '../../../../core/media/remote_image.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';

/// La photo du mouvement, en carte (maquette d'octobre 2026).
///
/// Elle vient du stockage objet, déposée depuis l'administration. Tant
/// qu'aucune n'est rattachée — le cas de la plupart des mouvements — la
/// carte garde son dégradé sombre et une grande icône atténuée : la fiche ne
/// change pas de forme selon qu'elle est illustrée ou non.
///
/// « Voir le mouvement » n'apparaît qu'avec une photo, et l'ouvre en grand :
/// le catalogue ne porte pas de vidéo, la carte ne promet donc pas d'en lire.
class ExerciseMediaCard extends StatelessWidget {
  const ExerciseMediaCard({required this.exercise, super.key});

  final ExerciseDetail exercise;

  /// Rapport largeur / hauteur de la maquette.
  static const double aspectRatio = 16 / 9;
  static const double _placeholderIconSize = 88;
  static const double _placeholderAlpha = 0.22;

  @override
  Widget build(BuildContext context) {
    final imageUrl = exercise.imageUrl;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: const BoxDecoration(
          borderRadius: AppRadius.lgAll,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.darkBorder),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Le fond est TOUJOURS posé : les photos sont détourées, donc
              // transparentes — sans lui, la figure flotterait sur le vide.
              _Placeholder(showIcon: imageUrl == null),
              if (imageUrl != null) ...[
                RemoteImage(
                  url: imageUrl,
                  placeholder: const SizedBox.shrink(),
                  // Détourée : `contain` garde la figure entière, `cover` la
                  // rognerait pour remplir le cadre.
                  fit: BoxFit.contain,
                  semanticLabel: 'Photo du mouvement',
                  decodeWidth: MediaQuery.sizeOf(context).width.round(),
                ),
                const _BottomShade(),
                Positioned(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: _ShowMovement(exercise: exercise, imageUrl: imageUrl),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Le bas de la photo s'assombrit sous « Voir le mouvement » : le libellé
/// reste lisible sur une photo claire.
class _BottomShade extends StatelessWidget {
  const _BottomShade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.55, 1],
          colors: [AppColors.backdropClear, AppColors.backdropVeil],
        ),
      ),
    );
  }
}

class _ShowMovement extends StatelessWidget {
  const _ShowMovement({required this.exercise, required this.imageUrl});

  final ExerciseDetail exercise;
  final String imageUrl;

  static const double _badgeSize = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Voir le mouvement en grand',
      excludeSemantics: true,
      // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
      onTap: () => _open(context),
      child: InkWell(
        borderRadius: AppRadius.fullAll,
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _badgeSize,
                height: _badgeSize,
                decoration: const BoxDecoration(
                  color: AppColors.darkSurfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.play,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Voir le mouvement',
                style: AppTypography.subheading.copyWith(
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) {
    return showAppDialog<void>(
      context,
      builder: (dialogContext) => AppPopupCard(
        icon: AppIcons.play,
        title: exercise.name,
        message: 'Pince la photo pour l’agrandir.',
        content: ClipRRect(
          borderRadius: AppRadius.cardSecondaryAll,
          child: InteractiveViewer(
            maxScale: 4,
            child: RemoteImage(
              url: imageUrl,
              placeholder: const SizedBox.shrink(),
              semanticLabel: 'Photo du mouvement',
            ),
          ),
        ),
        actions: [
          AppButton(
            label: 'Fermer',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}

/// Repli de la carte : dégradé sombre et, sans photo, icône très atténuée.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.showIcon});

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neutral900, AppColors.neutral950],
        ),
      ),
      child: showIcon
          ? ExcludeSemantics(
              child: Center(
                child: Icon(
                  AppIcons.workout,
                  size: ExerciseMediaCard._placeholderIconSize,
                  color: AppColors.primaryLight.withValues(
                    alpha: ExerciseMediaCard._placeholderAlpha,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
