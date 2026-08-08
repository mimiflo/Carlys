import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';
import '../controllers/dashboard_controllers.dart';

/// « Ta semaine » : en-tête de section puis 7 barres — séances faites en
/// violet atténué, jour courant en accent, jours sans séance en piste neutre.
///
/// La hauteur d'une barre suit le volume réel du jour, rapporté au meilleur
/// jour de la semaine.
class WeekBars extends StatelessWidget {
  const WeekBars({required this.week, super.key});

  final ProgressOverviewEntity? week;

  /// Géométrie de la maquette : barres de 46 au plus, talon visible pour les
  /// jours vides.
  static const double _maxHeight = 46;
  static const double _minHeight = 10;
  static const double _sessionFloor = 18;

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
        if (byDay[index] > maxVolume) {
          maxVolume = byDay[index];
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Ta semaine',
          trailing: '$sessions / $weeklySessionsTarget séances',
          trailingTone: AppSectionTrailingTone.primary,
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: '$sessions séance${sessions > 1 ? 's' : ''} '
              'sur $weeklySessionsTarget cette semaine',
          child: ExcludeSemantics(
            child: SizedBox(
              height: _maxHeight,
              child: Row(
                children: [
                  for (var day = 0; day < 7; day++) ...[
                    if (day > 0) const SizedBox(width: AppSpacing.xs),
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
          ),
        ),
      ],
    );
  }
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
    final height = hasSession
        ? WeekBars._sessionFloor +
            (WeekBars._maxHeight - WeekBars._sessionFloor) *
                fraction.clamp(0.0, 1.0)
        : WeekBars._minHeight;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: AppRadius.smAll,
        ),
      ),
    );
  }
}
