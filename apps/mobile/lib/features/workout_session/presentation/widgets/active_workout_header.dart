import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// En-tête de la séance active : fermer, chrono mono, terminer.
class ActiveWorkoutHeader extends StatelessWidget {
  const ActiveWorkoutHeader({
    required this.startedAt,
    required this.onClose,
    required this.onFinish,
    super.key,
  });

  final DateTime startedAt;
  final VoidCallback onClose;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Abandonner la séance',
            onPressed: onClose,
            icon: const Icon(
              AppIcons.close,
              color: AppColors.darkTextSecondary,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const AppSectionLabel('Séance en cours'),
                const SizedBox(height: 4),
                _ElapsedTimer(startedAt: startedAt),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Terminer la séance',
            onPressed: onFinish,
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElapsedTimer extends StatelessWidget {
  const _ElapsedTimer({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      builder: (context, snapshot) {
        final elapsed =
            (snapshot.data ?? DateTime.now()).difference(startedAt.toLocal());
        final hours = elapsed.inHours;
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return Text(
          hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds',
          style:
              AppTypography.metricL.copyWith(color: AppColors.darkTextPrimary),
          semanticsLabel: 'Durée écoulée',
        );
      },
    );
  }
}
