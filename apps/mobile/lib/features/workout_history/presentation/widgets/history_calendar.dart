import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../workout_session/domain/entities/workout.dart';

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// « novembre 2025 » — partagé avec l'écran d'historique.
String formatMonth(DateTime month) =>
    '${_months[month.month - 1]} ${month.year}';

/// Grille calendaire (2g) : jour avec séance = pastille violette, jour de
/// record = accent, jour vide = piste neutre. Cellule 36, gap 8.
class HistoryCalendar extends StatelessWidget {
  const HistoryCalendar({
    required this.month,
    required this.entries,
    required this.records,
    super.key,
  });

  final DateTime month;
  final List<WorkoutHistoryEntry> entries;
  final List<PersonalRecordEntry>? records;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month).weekday; // 1=lundi
    final today = DateTime.now();

    final sessionDays = <int>{};
    for (final entry in entries) {
      sessionDays.add(entry.session.startedAt.toLocal().day);
    }
    final recordDays = <int>{};
    for (final record in records ?? const <PersonalRecordEntry>[]) {
      final local = record.achievedAt.toLocal();
      if (local.year == month.year && local.month == month.month) {
        recordDays.add(local.day);
      }
    }

    return Semantics(
      label: '${sessionDays.length} jours de séance en ${formatMonth(month)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 7;
          const gap = 8.0;
          final cell = (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var blank = 1; blank < firstWeekday; blank++)
                SizedBox(width: cell, height: 36),
              for (var day = 1; day <= daysInMonth; day++)
                _DayCell(
                  day: day,
                  width: cell,
                  isToday: today.year == month.year &&
                      today.month == month.month &&
                      today.day == day,
                  hasSession: sessionDays.contains(day),
                  hasRecord: recordDays.contains(day),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.width,
    required this.isToday,
    required this.hasSession,
    required this.hasRecord,
  });

  final int day;
  final double width;
  final bool isToday;
  final bool hasSession;
  final bool hasRecord;

  @override
  Widget build(BuildContext context) {
    final (background, textColor) = hasRecord
        ? (AppColors.accent, AppColors.darkBackground)
        : hasSession
            ? (AppColors.primaryFill, AppColors.darkTextPrimary)
            : (AppColors.gaugeTrack, AppColors.darkTextTertiary);

    return Container(
      width: width,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.mdAll,
        border: isToday ? Border.all(color: AppColors.primaryLight) : null,
      ),
      child: Text(
        '$day',
        style: AppTypography.labelMono.copyWith(color: textColor),
      ),
    );
  }
}
