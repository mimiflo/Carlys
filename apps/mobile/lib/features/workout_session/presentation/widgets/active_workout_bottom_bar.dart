import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/workout_controllers.dart';

/// Barre basse en verre de la séance active (maquette 2e).
///
/// Pendant le repos : anneau de progression, temps restant et bouton
/// « Passer ». Sinon : clôture de la séance.
class ActiveWorkoutBottomBar extends ConsumerWidget {
  const ActiveWorkoutBottomBar({required this.onFinish, super.key});

  final VoidCallback onFinish;

  /// Géométrie de la maquette : voile flouté à 20, fond à 90 %.
  static const double _blur = 20;
  static const double _veilAlpha = 0.9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkBackground.withValues(alpha: _veilAlpha),
            border: const Border(
              top: BorderSide(color: AppColors.darkBorder),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              AppSpacing.lg + bottomInset,
            ),
            child: AnimatedSize(
              duration: AppMotion.resolve(context, AppMotion.normal),
              curve: AppMotion.standard,
              child: timer == null
                  ? _FinishButton(onPressed: onFinish)
                  : _RestRow(
                      timer: timer,
                      onSkip: () => ref.read(restTimerProvider.notifier).stop(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne de repos : anneau, libellés et action de reprise anticipée.
class _RestRow extends StatelessWidget {
  const _RestRow({required this.timer, required this.onSkip});

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

/// Clôture de séance — action secondaire : l'accent reste sur la validation
/// de série (une seule action accent par écran).
class _FinishButton extends StatelessWidget {
  const _FinishButton({required this.onPressed});

  final VoidCallback onPressed;

  static const double _iconSize = 19;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkTextPrimary,
          textStyle:
              AppTypography.subheading.copyWith(fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonAll,
            side: BorderSide(color: AppColors.darkBorderStrong),
          ),
        ),
        onPressed: onPressed,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.check, size: _iconSize),
            SizedBox(width: AppSpacing.xs),
            Text('Terminer la séance'),
          ],
        ),
      ),
    );
  }
}
