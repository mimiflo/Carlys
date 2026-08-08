import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/workout_controllers.dart';

/// Ligne de repos de la barre basse : anneau de progression, temps restant et
/// reprise anticipée.
///
/// Le repos vient du plan quand la séance suit un modèle, sinon de la série
/// précédente — cette ligne n'affiche que la durée qu'on lui donne.
class RestTimerRow extends StatelessWidget {
  const RestTimerRow({required this.timer, required this.onSkip, super.key});

  final RestTimerState timer;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final remaining = formatChrono(timer.remaining.inSeconds);

    return Semantics(
      liveRegion: true,
      label: 'Repos en cours, temps restant $remaining',
      child: Row(
        children: [
          _RestRing(progress: timer.progress, label: remaining),
          const SizedBox(width: AppSpacing.gapRow),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repos en cours',
                  style: AppTypography.subheading.copyWith(
                    fontSize: 14,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Prochaine série dans $remaining',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              backgroundColor: AppColors.accentBadgeBg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gapRow,
                vertical: AppSpacing.gapTile,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: AppTypography.label.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.lgAll,
                side: BorderSide(color: AppColors.accentBadgeBorder),
              ),
            ),
            onPressed: onSkip,
            child: const Text('Passer'),
          ),
        ],
      ),
    );
  }
}

/// Anneau de repos : arc primaire sur piste neutre, temps restant au centre.
class _RestRing extends StatelessWidget {
  const _RestRing({required this.progress, required this.label});

  final double progress;
  final String label;

  static const double _diameter = 52;
  static const double _stroke = 5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: CustomPaint(
        painter: _RestRingPainter(progress: progress),
        child: Center(
          child: Text(
            label,
            style: AppTypography.metricS.copyWith(
              fontSize: 13,
              color: AppColors.primaryLight,
            ),
          ),
        ),
      ),
    );
  }
}

class _RestRingPainter extends CustomPainter {
  const _RestRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _RestRing._stroke) / 2;

    // Trou central : la valeur reste lisible par-dessus le voile flouté.
    canvas.drawCircle(
      center,
      radius - _RestRing._stroke / 2,
      Paint()..color = AppColors.darkSurfaceAlt,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _RestRing._stroke
      ..color = AppColors.gaugeTrack;
    canvas.drawCircle(center, radius, track);

    final fraction = progress.clamp(0.0, 1.0);
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _RestRing._stroke
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(_RestRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
