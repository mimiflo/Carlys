import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/generation_report.dart';

/// Ce que la génération a décidé, montré à la personne concernée.
///
/// Elle ne montre pas seulement le plan : elle montre CE QU'IL A FALLU
/// CÉDER. Un générateur qui rend huit semaines sans dire qu'il n'a trouvé
/// que six séries de dos par semaine au lieu de neuf laisse croire à un plan
/// complet — et la déception arrive trois semaines plus tard, sans
/// explication. Les phrases viennent du serveur, qui seul connaît la règle.
Future<void> showGenerationReportSheet(
  BuildContext context,
  GeneratedProgramResult result,
) {
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => _GenerationReportSheet(result: result),
  );
}

class _GenerationReportSheet extends StatelessWidget {
  const _GenerationReportSheet({required this.result});

  final GeneratedProgramResult result;

  @override
  Widget build(BuildContext context) {
    final report = result.report;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.name, style: AppTypography.title),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${result.weeksCount} semaines · ${report.sessionsPerWeek} séances '
            'par semaine · ${report.templatesCreated} séances préparées',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (report.split.isNotEmpty) ...[
            const AppSectionLabel('Ta semaine type'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: [for (final jour in report.split) AppPill(label: jour)],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.isSatisfied && report.notes.isEmpty)
                    const _Ligne(
                      icon: AppIcons.checkCircle,
                      color: AppColors.success,
                      text:
                          'Toutes les règles de ton objectif sont tenues : '
                          'volume, récupération et durée de séance.',
                    ),
                  for (final relaxation in report.relaxations)
                    _Ligne(
                      icon: AppIcons.info,
                      color: AppColors.warning,
                      text: relaxation.message,
                    ),
                  for (final note in report.notes)
                    _Ligne(
                      icon: AppIcons.info,
                      color: AppColors.darkTextSecondary,
                      text: note,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Voir mon programme',
            isExpanded: true,
            onPressed: () {
              // La feuille se ferme AVANT de naviguer : sinon elle resterait
              // empilée au-dessus du détail, et le retour la rouvrirait.
              Navigator.of(context).pop();
              GoRouter.of(context).push('/programs/${result.programId}');
            },
          ),
        ],
      ),
    );
  }
}

/// Une explication : son icône, sa couleur, sa phrase. Rien d'autre.
class _Ligne extends StatelessWidget {
  const _Ligne({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
