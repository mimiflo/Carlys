import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/workout_controllers.dart';

/// Ligne de repos de la barre basse : anneau de progression, temps restant
/// sur la durée prévue, et reprise anticipée.
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
    final total = _spoken(timer.total.inSeconds);

    final info = Semantics(
      liveRegion: true,
      label: 'Repos en cours, temps restant $remaining sur $total',
      excludeSemantics: true,
      child: Row(
        children: [
          _RestRing(progress: timer.progress),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEMPS DE REPOS',
                  style: AppTypography.labelMono.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    remaining,
                    maxLines: 1,
                    style: AppTypography.resized(
                      AppTypography.metricL,
                      34,
                    ).copyWith(color: AppColors.darkTextPrimary),
                  ),
                ),
                Text(
                  'sur $total',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final skip = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: const Size(AppSpacing.xxl * 2, AppSpacing.touchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        textStyle: AppTypography.heading,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
      ),
      onPressed: onSkip,
      child: const Text('Passer'),
    );
    // Texte agrandi : le décompte et « Passer » ne tiennent plus sur une
    // ligne. Le bouton passe alors dessous, sur toute la largeur.
    if (MediaQuery.textScalerOf(context).scale(10) > 13) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          const SizedBox(height: AppSpacing.sm),
          skip,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: info),
        const SizedBox(width: AppSpacing.sm),
        skip,
      ],
    );
  }

  /// « 1 min 30 », « 2 min », « 45 s » : la durée totale, dite comme on la
  /// lit, sous le décompte.
  static String _spoken(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes == 0) {
      return '$rest s';
    }
    return rest == 0
        ? '$minutes min'
        : '$minutes min ${rest.toString().padLeft(2, '0')}';
  }
}

/// Anneau de repos : arc violet sur piste neutre, le chronomètre au centre.
class _RestRing extends StatelessWidget {
  const _RestRing({required this.progress});

  final double progress;

  static const double _diameter = 72;
  static const double _stroke = 6;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: CustomPaint(
        painter: _RestRingPainter(progress: progress),
        child: const Center(
          child: Icon(AppIcons.timer, size: 28, color: AppColors.primaryLight),
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
