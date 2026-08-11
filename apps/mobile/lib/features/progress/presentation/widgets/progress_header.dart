import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';

/// En-tête de la progression : titre à gauche, pastille de période à droite.
///
/// La pastille est unique — elle ouvre une feuille listant les périodes
/// réellement supportées par l'API.
class ProgressHeader extends ConsumerWidget {
  const ProgressHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(progressPeriodProvider);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Progression',
            style: AppTypography.display.copyWith(
              fontSize: 27,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        AppPill(
          label: period.label,
          mono: true,
          onTap: () => _choosePeriod(context, ref, period),
        ),
      ],
    );
  }

  Future<void> _choosePeriod(
    BuildContext context,
    WidgetRef ref,
    ProgressPeriod current,
  ) async {
    final chosen = await showAppSheet<ProgressPeriod>(
      context,
      style: AppSheetStyle.picker,
      builder: (_) => _PeriodSheet(current: current),
    );
    if (chosen != null && chosen != current) {
      ref.read(progressPeriodProvider.notifier).state = chosen;
    }
  }
}

/// Feuille de choix de la période analysée.
class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.current});

  final ProgressPeriod current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(title: 'Période analysée'),
            const SizedBox(height: AppSpacing.sm),
            for (final period in ProgressPeriod.values) ...[
              AppListRow(
                title: period.label,
                leading: AppIcons.calendar,
                leadingTint: period == current
                    ? AppColors.accent
                    : AppColors.primaryLight,
                trailing: period == current
                    ? const Icon(
                        AppIcons.check,
                        size: 20,
                        color: AppColors.accent,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(period),
              ),
              if (period != ProgressPeriod.values.last)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}
