import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/consistency_week.dart';
import 'section_title_bar.dart';

/// LA SÉRIE DE CONSTANCE, réduite à sept traits.
///
/// Sept ronds de 38 faisaient une rangée de jetons dont un seul était allumé :
/// six échecs, là où il n'y a qu'une semaine en cours. Sept traits de quatre
/// points disent la même chose sans juger — ce qui est fait est plein, ce qui
/// vient est sourd, et aujourd'hui est en pointillé parce que la journée
/// n'est pas finie.
class ConsistencyStreak extends StatelessWidget {
  const ConsistencyStreak({required this.week, super.key});

  /// `null` tant que l'historique n'est pas chargé.
  final ConsistencyWeek? week;

  /// Géométrie : trait de 4 sur toute la largeur disponible, initiale dessous.
  static const double _barHeight = 4;
  static const double _gap = 6;

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
            SectionTitleBar(
              icon: AppIcons.streak,
              iconColor: AppColors.accent,
              label: 'Série de constance',
              trailing: _headline(data),
              trailingColor:
                  streak > 0 ? AppColors.accent : AppColors.darkTextTertiary,
              // La flamme RESPIRE tant que la série tient : le seul mouvement
              // permanent de l'accueil, et il dit quelque chose.
              leading: streak > 0
                  ? const AppLivingFlame(size: 14, color: AppColors.accent)
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (var index = 0; index < 7; index++) ...[
                  if (index > 0) const SizedBox(width: _gap),
                  Expanded(child: _DayBar(day: data?.days[index])),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.gapTile),
            Row(
              children: [
                for (var index = 0; index < 7; index++) ...[
                  if (index > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: _DayInitial(
                      day: data?.days[index],
                      fallbackIndex: index,
                    ),
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
      1 => '1 jour',
      final days => '$days jours',
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

/// Le trait d'un jour : plein s'il est tenu, pointillé aujourd'hui, sourd
/// pour ce qui n'est pas encore arrivé.
class _DayBar extends StatelessWidget {
  const _DayBar({required this.day});

  final ConsistencyDay? day;

  @override
  Widget build(BuildContext context) {
    final data = day;
    final trained = data?.trained ?? false;
    final isToday = data?.isToday ?? false;

    if (isToday && !trained) {
      // Le trait est ARRONDI au clip, jamais au tiret : un tiret de quatre
      // points arrondi sur une piste de quatre d'épaisseur devient un rond,
      // et la journée en cours se lirait comme une file de perles.
      return const ClipRRect(
        borderRadius: AppRadius.fullAll,
        child: SizedBox(
          height: ConsistencyStreak._barHeight,
          child: CustomPaint(painter: _PendingBar(), size: Size.infinite),
        ),
      );
    }

    return Container(
      height: ConsistencyStreak._barHeight,
      decoration: BoxDecoration(
        color: trained ? AppColors.accent : AppColors.pendingBar,
        borderRadius: AppRadius.fullAll,
      ),
    );
  }
}

/// La journée en cours : elle n'est ni tenue ni manquée, elle est ouverte.
class _PendingBar extends CustomPainter {
  const _PendingBar();

  static const double _dash = 4;

  @override
  void paint(Canvas canvas, Size size) {
    // Deux tons qui alternent, sans trou : la journée est OUVERTE, pas
    // absente. Un vrai vide entre les tirets la ferait ressembler à un jour
    // manqué.
    final full = Paint()..color = AppColors.primaryLight;
    final soft = Paint()..color = AppColors.pendingBarSoft;
    for (var x = 0.0; x < size.width; x += _dash * 2) {
      canvas
        ..drawRect(Rect.fromLTWH(x, 0, _dash, size.height), full)
        ..drawRect(Rect.fromLTWH(x + _dash, 0, _dash, size.height), soft);
    }
  }

  @override
  bool shouldRepaint(_PendingBar oldDelegate) => false;
}

class _DayInitial extends StatelessWidget {
  const _DayInitial({required this.day, required this.fallbackIndex});

  final ConsistencyDay? day;
  final int fallbackIndex;

  static const List<String> _initials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final data = day;
    final trained = data?.trained ?? false;
    final isToday = data?.isToday ?? false;

    final (color, weight) = switch ((trained, isToday)) {
      (true, _) => (AppColors.accent, FontWeight.w500),
      (false, true) => (AppColors.primaryLight, FontWeight.w700),
      _ => (AppColors.textMuted, FontWeight.w500),
    };

    return Text(
      data?.initial ?? _initials[fallbackIndex],
      textAlign: TextAlign.center,
      style: AppTypography.labelMono.copyWith(
        fontSize: 9,
        fontWeight: weight,
        color: color,
      ),
    );
  }
}
