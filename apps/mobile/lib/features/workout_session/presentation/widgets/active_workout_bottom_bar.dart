import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/workout_controllers.dart';
import 'rest_timer_row.dart';

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
            child: _Morph(
              duration: AppMotion.resolve(context, AppMotion.normal),
              child: timer == null
                  ? _FinishButton(onPressed: onFinish)
                  : RestTimerRow(
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

/// Transition de hauteur entre le bouton de clôture et la ligne de repos.
///
/// Avec la réduction d'animations système, la durée vaut zéro : `AnimatedSize`
/// se relance alors pendant sa propre mise en page. On bascule donc sans
/// animation dans ce cas — c'est exactement ce que la préférence demande.
class _Morph extends StatelessWidget {
  const _Morph({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) {
      return child;
    }
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.standard,
      child: child,
    );
  }
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
