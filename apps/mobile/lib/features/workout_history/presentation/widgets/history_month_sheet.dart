import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Sélecteur de mois ouvert par l'icône calendrier de l'en-tête.
///
/// Ne propose que des mois réels : ceux qui portent des séances, plus le mois
/// courant. Renvoie le mois choisi, ou `null` si la feuille est refermée.
Future<DateTime?> showHistoryMonthSheet(
  BuildContext context, {
  required List<DateTime> months,
  required DateTime selected,
}) {
  return showAppSheet<DateTime>(
    context,
    style: AppSheetStyle.picker,
    builder: (_) => _MonthSheet(months: months, selected: selected),
  );
}

class _MonthSheet extends StatelessWidget {
  const _MonthSheet({required this.months, required this.selected});

  final List<DateTime> months;
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    // Les marges système (haut ET bas) sont déjà prises par `showAppSheet`.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(title: 'Mois affiché'),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: months.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final month = months[index];
                  final isSelected = month.year == selected.year &&
                      month.month == selected.month;

                  return AppListRow(
                    title: formatMonthYearCapitalized(month),
                    leading: AppIcons.calendar,
                    leadingTint:
                        isSelected ? AppColors.accent : AppColors.primaryLight,
                    trailing: isSelected
                        ? const Icon(
                            AppIcons.check,
                            size: 20,
                            color: AppColors.accent,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(month),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
