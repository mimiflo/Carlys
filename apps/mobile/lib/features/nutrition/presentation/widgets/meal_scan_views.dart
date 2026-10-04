import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Avant la photo : ce que fait le scan, et les deux façons de la donner.
class MealScanIntro extends StatelessWidget {
  const MealScanIntro({
    required this.onCamera,
    required this.onGallery,
    super.key,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  static const double _badge = 88;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              Container(
                width: _badge,
                height: _badge,
                decoration: const BoxDecoration(
                  gradient: AppColors.cta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.mealScan,
                  color: AppColors.darkTextPrimary,
                  size: _badge / 2,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Photographie ton assiette, vue de dessus',
                textAlign: TextAlign.center,
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'L’IA reconnaît les aliments et estime leurs grammes ; la '
                'table Ciqual en donne les valeurs. Tu vérifies tout avant '
                'd’enregistrer.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Prendre la photo',
          icon: AppIcons.mealPhoto,
          isExpanded: true,
          onPressed: onCamera,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Choisir une photo',
          icon: AppIcons.mealPhotoGallery,
          variant: AppButtonVariant.secondary,
          isExpanded: true,
          onPressed: onGallery,
        ),
      ],
    );
  }
}

/// La photo prise, pleine largeur, aux coins de carte.
class _ScanPhoto extends StatelessWidget {
  const _ScanPhoto(this.photo);

  final Uint8List photo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.cardMain),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.memory(
          photo,
          fit: BoxFit.cover,
          semanticLabel: 'Photo de ton assiette',
        ),
      ),
    );
  }
}

/// Pendant l'analyse : la photo, et le temps écoulé — l'IA y passe une à
/// deux minutes sur nos machines, mieux vaut le dire que laisser croire à
/// une panne.
class MealScanProgress extends StatefulWidget {
  const MealScanProgress({required this.photo, required this.since, super.key});

  final Uint8List? photo;
  final DateTime since;

  @override
  State<MealScanProgress> createState() => _MealScanProgressState();
}

class _MealScanProgressState extends State<MealScanProgress> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = DateTime.now().difference(widget.since).inSeconds;
    final elapsed =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final photo = widget.photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photo != null) ...[
          _ScanPhoto(photo),
          const SizedBox(height: AppSpacing.lg),
        ],
        const AppLoadingIndicator(label: 'L’IA regarde ton assiette'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$elapsed · une à deux minutes en général',
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
      ],
    );
  }
}

/// Le scan n'a rien donné : pourquoi, et les deux suites possibles.
class MealScanFailure extends StatelessWidget {
  const MealScanFailure({
    required this.photo,
    required this.message,
    required this.onRetry,
    required this.onByHand,
    super.key,
  });

  final Uint8List? photo;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onByHand;

  @override
  Widget build(BuildContext context) {
    final shown = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shown != null) ...[
          _ScanPhoto(shown),
          const SizedBox(height: AppSpacing.md),
        ],
        AppErrorState(
          title: 'Pas de repas reconnu',
          message: message,
          icon: AppIcons.mealScan,
          retryLabel: 'Reprendre une photo',
          onRetry: onRetry,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Saisir à la main',
          variant: AppButtonVariant.ghost,
          isExpanded: true,
          onPressed: onByHand,
        ),
      ],
    );
  }
}
