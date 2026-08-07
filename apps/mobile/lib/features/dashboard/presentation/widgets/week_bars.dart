import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';

/// « Ta semaine » : 7 barres (hauteur max 56) — séances faites en violet
/// atténué, aujourd'hui en accent, jours vides en piste neutre.
class WeekBars extends StatelessWidget {
  const WeekBars({required this.week, super.key});

  final ProgressOverviewEntity? week;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final points = week?.points ?? const <ProgressPoint>[];
    final sessions = week?.sessionsCount ?? 0;

    // Volume par jour de la semaine courante (lundi..dimanche).
    final byDay = List<double>.filled(7, 0);
    var maxVolume = 0.0;
    for (final point in points) {
      final local = point.bucketStart.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final index = day.difference(monday).inDays;
      if (index >= 0 && index < 7) {
        byDay[index] += point.volumeKg;
        if (byDay[index] > maxVolume) maxVolume = byDay[index];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ta semaine',
                style: AppTypography.heading
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
            ),
            AppSectionLabel(
              '$sessions / ${FormeCardTarget.weekly} séances',
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var day = 0; day < 7; day++) ...[
                if (day > 0) const SizedBox(width: 8),
                Expanded(
                  child: _DayBar(
                    fraction: maxVolume == 0 ? 0 : byDay[day] / maxVolume,
                    isToday: day == now.weekday - 1,
                    hasSession: byDay[day] > 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Objectif hebdomadaire partagé entre la carte de forme et les barres.
abstract final class FormeCardTarget {
  static const int weekly = 5;
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.fraction,
    required this.isToday,
    required this.hasSession,
  });

  final double fraction;
  final bool isToday;
  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    final color = isToday && hasSession
        ? AppColors.accent
        : hasSession
            ? AppColors.primaryFill
            : AppColors.gaugeTrack;
    final height = hasSession ? (12 + 44 * fraction.clamp(0.0, 1.0)) : 12.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
