import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';
import 'title_regalia.dart';

/// Le titre atteint, les points, et le chemin vers le suivant.
///
/// L'écrin monte en majesté avec [regaliaTitle] — liseré, dégradé, halo,
/// couronne. C'est ce qui fait qu'un palier se RESSENT au lieu de se lire.
///
/// La majesté suit le titre le plus haut jamais atteint, pas le titre du
/// moment : personne ne doit voir son écran se ternir après deux semaines
/// d'arrêt. Le total, lui, dit la vérité du présent.
class ProgressionTitleCard extends StatefulWidget {
  const ProgressionTitleCard({
    required this.profile,
    required this.regaliaTitle,
    super.key,
  });

  final ProgressionProfile profile;

  /// Titre qui décide de l'écrin. Jamais inférieur à celui du profil.
  final CarlysTitle regaliaTitle;

  /// La jauge se remplit sous les yeux à l'ouverture : une barre déjà pleine
  /// à l'arrivée ne raconte pas le chemin parcouru.
  static const Duration fillDuration = Duration(milliseconds: 900);

  @override
  State<ProgressionTitleCard> createState() => _ProgressionTitleCardState();
}

class _ProgressionTitleCardState extends State<ProgressionTitleCard> {
  double _gauge = 0;

  @override
  void initState() {
    super.initState();
    // Après la première image : la jauge part de zéro et rejoint sa valeur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _gauge = widget.profile.progressToNextTitle);
      }
    });
  }

  @override
  void didUpdateWidget(ProgressionTitleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _gauge = widget.profile.progressToNextTitle;
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final next = profile.title.next;
    final remaining = profile.pointsToNextTitle;
    final regalia = TitleRegalia.of(widget.regaliaTitle);

    return DecoratedBox(
      decoration: regalia.decoration,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md + AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppSectionLabel('Ton titre'),
                if (regalia.crowned) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    AppIcons.crown,
                    size: 14,
                    color: AppColors.primaryLight,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        regalia.gradient.createShader(bounds),
                    child: Text(
                      profile.title.label,
                      style: AppTypography.display
                          .copyWith(color: AppColors.neutral0),
                    ),
                  ),
                ),
                Text(
                  '${profile.points}',
                  style: AppTypography.metricL
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '/ $maxTotal',
                  style: AppTypography.labelMono
                      .copyWith(color: AppColors.darkTextTertiary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _gauge),
                duration: AppMotion.resolve(
                  context,
                  ProgressionTitleCard.fillDuration,
                ),
                curve: AppMotion.standard,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppColors.gaugeTrack,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryFlash,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              next == null || remaining == null
                  ? 'Dernier titre atteint. Le reste, c’est la suite de ton '
                      'histoire.'
                  : 'Encore $remaining points avant ${next.label}.',
              style: AppTypography.label
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
