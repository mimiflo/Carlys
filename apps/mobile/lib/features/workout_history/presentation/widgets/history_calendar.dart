import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../utils/history_stats.dart';

/// Géométrie de la grille (maquette) : 7 colonnes, gouttière 6, cellules
/// carrées sans numéro de jour.
const int _columns = 7;
const double _cellGap = 6;
const double _cardPadding = 18;
const double _headerGap = 13;

/// Carte calendaire du mois : en-tête « Novembre 2025 » + nombre de séances,
/// puis une grille de chaleur où l'intensité vient du volume réel du jour.
class HistoryCalendar extends StatelessWidget {
  const HistoryCalendar({required this.stats, super.key});

  final HistoryMonthStats stats;

  @override
  Widget build(BuildContext context) {
    final month = stats.month;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // `weekday` vaut 1 pour lundi : la grille démarre donc sur le lundi.
    final leadingBlanks = DateTime(month.year, month.month).weekday - 1;
    final usedCells = leadingBlanks + daysInMonth;
    final totalCells = ((usedCells + _columns - 1) ~/ _columns) * _columns;
    final sessionsLabel = stats.sessionsCount > 1
        ? '${formatThousands(stats.sessionsCount)} séances'
        : '${formatThousands(stats.sessionsCount)} séance';

    return Container(
      padding: const EdgeInsets.all(_cardPadding),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: formatMonthYearCapitalized(month),
            trailing: sessionsLabel,
            trailingTone: AppSectionTrailingTone.accent,
          ),
          const SizedBox(height: _headerGap),
          Semantics(
            label: '$sessionsLabel en ${formatMonthYear(month)}',
            excludeSemantics: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cell =
                    (constraints.maxWidth - _cellGap * (_columns - 1)) /
                    _columns;

                return Wrap(
                  spacing: _cellGap,
                  runSpacing: _cellGap,
                  children: [
                    for (var index = 0; index < totalCells; index++)
                      _DayCell(
                        size: cell,
                        color: _cellColor(
                          index - leadingBlanks + 1,
                          daysInMonth: daysInMonth,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _cellColor(int day, {required int daysInMonth}) {
    if (day < 1 || day > daysInMonth) {
      return AppColors.heatOutOfMonth;
    }
    if (stats.hasRecord(day)) {
      return AppColors.accent;
    }
    if (stats.hasSession(day)) {
      return AppColors.heatFill(stats.intensity(day));
    }
    return AppColors.heatEmpty;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.smAll),
    );
  }
}
