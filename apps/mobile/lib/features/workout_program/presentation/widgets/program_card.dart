import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/program.dart';

/// Un programme dans la liste : nom, ampleur, avancement du plan, badge
/// « suivi » quand c'est celui en cours.
class ProgramCard extends StatelessWidget {
  const ProgramCard({required this.program, required this.onOpen, super.key});

  final ProgramSummary program;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: program.isActive ? AppColors.accent : AppColors.primaryLight,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: AppTypography.subheading
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                Text(
                  '${program.weeksCount} semaine'
                  '${program.weeksCount > 1 ? 's' : ''} · '
                  '${formatThousands(program.daysCount)} jour'
                  '${program.daysCount > 1 ? 's' : ''} planifié'
                  '${program.daysCount > 1 ? 's' : ''}',
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextTertiary),
                ),
              ],
            ),
          ),
          if (program.isActive) ...[
            const SizedBox(width: AppSpacing.xs),
            const AppSectionLabel('Suivi', color: AppColors.accent),
          ],
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }
}
