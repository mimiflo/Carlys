import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/consistency_week.dart';

/// **Série de constance** : label, « Jour N » avec sa flamme, puis les sept
/// jours de la semaine en ronds (L M M J V S D) — petite flamme au-dessus de
/// ceux qui ont été tenus.
///
/// Sans cadre de carte : elle vit dans la zone haute, aux côtés du cœur, dont
/// elle occupe le vide. Ce qu'elle montre, ce sont des séances RÉELLEMENT
/// terminées — jamais une estimation. Les jours à venir sont en retrait
/// plutôt qu'en échec : on ne reproche à personne de ne pas avoir déjà fait
/// demain.
class ConsistencyStreak extends StatelessWidget {
  const ConsistencyStreak({required this.week, super.key});

  /// `null` tant que l'historique n'est pas chargé.
  final ConsistencyWeek? week;

  /// Géométrie : rond de 38, gouttière à flamme réservée au-dessus pour que
  /// tous les ronds restent alignés, flamme ou pas.
  static const double _circleSize = 38;
  static const double _flameSlot = 16;
  static const double _flameSize = 13;
  static const double _headlineFlameSize = 18;
  static const double _labelSlot = 16;

  /// Hauteur totale du bloc. La zone haute s'en sert pour se réserver la
  /// place de la série SOUS le cœur, sans la mesurer après coup.
  static const double height =
      _labelSlot + AppSpacing.xs + _flameSlot + _circleSize;

  @override
  Widget build(BuildContext context) {
    final data = week;
    final streak = data?.streakDays ?? 0;

    return Semantics(
      label: _semanticsLabel(data),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SizedBox(
                    height: _labelSlot,
                    child: AppSectionLabel(
                      'Série de constance',
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ),
                if (streak > 0) ...[
                  // La flamme de tête RESPIRE tant que la série tient : le
                  // seul mouvement permanent de l'accueil, et il dit
                  // quelque chose.
                  const AppLivingFlame(
                    size: _headlineFlameSize,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Text(
                  _headline(data),
                  style: AppTypography.labelMono.copyWith(
                    fontSize: 12,
                    color: streak > 0
                        ? AppColors.accent
                        : AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (var index = 0; index < 7; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child:
                        _DayDot(day: data?.days[index], fallbackIndex: index),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _headline(ConsistencyWeek? week) {
    if (week == null) {
      return '—';
    }
    return switch (week.streakDays) {
      0 => 'À relancer',
      final days => 'Jour $days',
    };
  }

  static String _semanticsLabel(ConsistencyWeek? week) {
    if (week == null) {
      return 'Série de constance en cours de chargement';
    }
    final trained = week.trainedCount;
    final base = trained == 0
        ? 'Aucune séance cette semaine'
        : '$trained jour${trained > 1 ? 's' : ''} tenu'
            '${trained > 1 ? 's' : ''} cette semaine';
    if (week.streakDays == 0) {
      return '$base. Série à relancer.';
    }
    return '$base. Série en cours : jour ${week.streakDays}.';
  }
}

/// Un jour : la flamme si tenu, puis le rond à initiale.
class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.fallbackIndex});

  /// `null` pendant le chargement — le rond s'affiche alors en attente.
  final ConsistencyDay? day;

  /// Initiale à montrer tant que la donnée n'est pas là.
  final int fallbackIndex;

  static const List<String> _initials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final data = day;
    final trained = data?.trained ?? false;
    final isToday = data?.isToday ?? false;
    final isFuture = data?.isFuture ?? false;

    final (background, border, textColor) = switch ((trained, isToday)) {
      // Tenu : la flamme et l'accent, la seule couleur forte de la rangée.
      (true, _) => (
          AppColors.accentBadgeBg,
          AppColors.accentBadgeBorder,
          AppColors.accent,
        ),
      // Aujourd'hui, pas encore fait : la journée est ouverte, pas ratée.
      (false, true) => (
          AppColors.primaryFill,
          AppColors.primary,
          AppColors.neutral0,
        ),
      _ => (
          AppColors.gaugeTrack,
          AppColors.darkBorderStrong,
          isFuture ? AppColors.darkTextTertiary : AppColors.darkTextSecondary,
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: ConsistencyStreak._flameSlot,
          child: trained
              ? const Icon(
                  AppIcons.streak,
                  size: ConsistencyStreak._flameSize,
                  color: AppColors.accent,
                )
              : null,
        ),
        Opacity(
          opacity: isFuture ? 0.45 : 1,
          child: Container(
            height: ConsistencyStreak._circleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: Text(
              data?.initial ?? _initials[fallbackIndex],
              style: AppTypography.labelMono.copyWith(
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
