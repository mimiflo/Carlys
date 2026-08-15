import 'package:flutter/material.dart';

import '../../../../core/brand/carlys_manifesto.dart';
import '../../../../core/brand/carlys_value.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';

/// LE MANIFESTE : ce que Carlys défend, et les cinq valeurs qui en découlent.
///
/// Un rappel, pas une page d'accueil : on y vient quand on veut se souvenir
/// pourquoi on est là. D'où le plein écran, hors coquille, et une lecture
/// posée plutôt qu'un empilement de cartes.
///
/// Les valeurs sont montrées ICI parce que le manifeste les explique : elles
/// sont ensuite MESURÉES dans le profil de progression. Séparer le discours
/// du score est délibéré — un manifeste qui afficherait des points cesserait
/// d'être un manifeste.
class ManifestoScreen extends StatelessWidget {
  const ManifestoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          const Positioned.fill(
            child: AppSceneGlow(
              center: Alignment(0, -0.75),
              radius: 0.8,
              alpha: 0.18,
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.gutter,
                AppSpacing.gutter,
                bottomInset + AppSpacing.gapSection,
              ),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AppBackButton(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  carlysManifestoTitle,
                  style: AppTypography.display
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: AppSpacing.gapSection),
                for (final line in carlysManifesto) ...[
                  Text(
                    line,
                    style: AppTypography.heading.copyWith(
                      color: AppColors.darkTextPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.gapSection),
                const AppSectionLabel('Les cinq valeurs'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Elles ne sont pas décoratives : ce sont les axes de ton '
                  'profil de progression.',
                  style: AppTypography.body
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: AppSpacing.gapRow),
                for (final value in CarlysValue.values) ...[
                  _ValueRow(value: value),
                  const SizedBox(height: AppSpacing.gapRow),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une valeur : son nom, ce qu'elle demande.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.value});

  final CarlysValue value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.label.toUpperCase(),
            style: AppTypography.labelMono.copyWith(
              color: AppColors.primaryLight,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value.promise,
            style:
                AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}
