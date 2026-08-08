import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/consistency_week.dart';

/// **Série de constance** : les sept jours de la semaine en ronds (L M M J V
/// S D), une flamme au-dessus de ceux qui ont été tenus.
///
/// Ce qu'on montre, ce sont des séances RÉELLEMENT terminées — jamais une
/// estimation. Les jours à venir sont en retrait plutôt qu'en échec : on ne
/// reproche à personne de ne pas avoir déjà fait demain.
class ConsistencyStreak extends StatelessWidget {
  const ConsistencyStreak({required this.week, super.key});

  /// `null` tant que l'historique n'est pas chargé.
  final ConsistencyWeek? week;

  /// Géométrie : rond de 38, gouttière à flamme réservée au-dessus pour que
  /// tous les ronds restent alignés, flamme ou pas.
  static const double _circleSize = 38;
  static const double _flameSlot = 18;
  static const double _flameSize = 15;

  @override
  Widget build(BuildContext context) {
    final data = week;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Ta constance',
          trailing: _trailingLabel(data),
          trailingTone: data != null && data.streakDays > 0
              ? AppSectionTrailingTone.accent
              : AppSectionTrailingTone.tertiary,
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: _semanticsLabel(data),
          child: ExcludeSemantics(
            child: Row(
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
          ),
        ),
      ],
    );
  }

  static String _trailingLabel(ConsistencyWeek? week) {
    if (week == null) {
      return '—';
    }
    return switch (week.streakDays) {
      0 => 'À relancer',
      1 => '1 jour d’affilée',
      final days => '$days jours d’affilée',
    };
  }

  static String _semanticsLabel(ConsistencyWeek? week) {
    if (week == null) {
      return 'Constance de la semaine en cours de chargement';
    }
    final trained = week.trainedCount;
    final base = trained == 0
        ? 'Aucune séance cette semaine'
        : '$trained jour${trained > 1 ? 's' : ''} tenu'
            '${trained > 1 ? 's' : ''} cette semaine';
    if (week.streakDays == 0) {
      return '$base. Série à relancer.';
    }
    return '$base. Série en cours : ${week.streakDays} '
        'jour${week.streakDays > 1 ? 's' : ''} d’affilée.';
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
          Colors.transparent,
          AppColors.primary,
          AppColors.primaryLight,
        ),
      _ => (
          AppColors.gaugeTrack,
          AppColors.darkBorder,
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
