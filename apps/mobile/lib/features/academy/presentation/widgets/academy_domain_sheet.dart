import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';
import 'lesson_illustration.dart';

/// « Voir les 12 » : tous les domaines d'un coup d'œil, quand la barre de
/// pastilles n'en montre que les premiers. Rend le domaine choisi, ou `null`
/// si la feuille se ferme sans choix.
Future<AcademyCategory?> pickAcademyDomain(
  BuildContext context, {
  required List<AcademyCategory> domaines,
  required AcademyCategory? selected,
  required int Function(AcademyCategory) countOf,
}) {
  return showAppSheet<AcademyCategory>(
    context,
    style: AppSheetStyle.picker,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(title: 'Les ${domaines.length} domaines'),
            const SizedBox(height: AppSpacing.sm),
            for (final domaine in domaines) ...[
              AppListRow(
                title: domaine.label,
                subtitle: countOf(domaine) > 1
                    ? '${countOf(domaine)} leçons'
                    : '1 leçon',
                leading: academyCategoryIcon(domaine),
                trailing: domaine == selected
                    ? const Icon(AppIcons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(domaine),
              ),
              if (domaine != domaines.last)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    ),
  );
}
