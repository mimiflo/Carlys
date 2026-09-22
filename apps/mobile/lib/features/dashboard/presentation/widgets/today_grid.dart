import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/today_metrics.dart';
import 'today_gauge.dart';

/// AUJOURD'HUI : quatre mesures dans UNE surface.
///
/// Les filets en croix naissent d'un espacement d'un point sur un fond clair,
/// pas de bordures dessinées : quatre tuiles bordées chacune donnaient quatre
/// îlots posés sur le fond, là où il n'y a qu'un seul état du jour.
///
/// Chaque cellule dit ce qui est fait, ce qui était visé et ce qu'il reste.
/// La valeur seule ne vaut rien : « 654 kcal » n'est ni bon ni mauvais tant
/// qu'on ignore la cible.
class TodayGrid extends StatelessWidget {
  const TodayGrid({
    required this.metrics,
    this.onOpenHydration,
    this.onAddMeal,
    super.key,
  });

  final List<TodayMetric> metrics;

  /// Ouvre la feuille d'hydratation.
  final VoidCallback? onOpenHydration;

  /// Ouvre la feuille de saisie d'un repas.
  ///
  /// DEUX mesures se nourrissent donc depuis l'accueil, et les deux pour la
  /// même raison : boire et manger se décident plusieurs fois par jour, là
  /// où les séances et le poids ont leur propre moment. Ce sont aussi les
  /// deux seules dont le chiffre du jour reste faux tant qu'on n'a pas
  /// ouvert un autre onglet — la tuile montrait le manque sans offrir de le
  /// combler. Les deux autres cellules viennent des séances et n'ont
  /// toujours aucun geste : leur en donner un ferait croire le contraire.
  final VoidCallback? onAddMeal;

  /// Épaisseur du filet interne — c'est l'espacement qui le dessine.
  static const double _rule = 1;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.listRow),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Padding(
          // Deux points de marge : la bordure extérieure ne doit pas se
          // confondre avec les filets internes.
          padding: const EdgeInsets.all(2),
          child: ColoredBox(
            color: AppColors.gridRule,
            child: Column(
              children: [
                for (var row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: _rule),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _cell(metrics[row * 2])),
                        const SizedBox(width: _rule),
                        Expanded(child: _cell(metrics[row * 2 + 1])),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  TodayCell _cell(TodayMetric metric) => TodayCell(
    metric: metric,
    onTap: switch (metric.kind) {
      TodayMetricKind.hydratation => onOpenHydration,
      TodayMetricKind.calories => onAddMeal,
      _ => null,
    },
  );
}

/// Une mesure : son libellé, son chiffre face à sa cible, sa jauge, son reste.
class TodayCell extends StatelessWidget {
  const TodayCell({required this.metric, this.onTap, super.key});

  final TodayMetric metric;

  /// Rend la cellule actionnable. Une mesure qu'on peut nourrir ou dont la
  /// cible reste à calculer mérite un geste ; les autres n'en ont pas et ne
  /// doivent surtout pas faire croire le contraire.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = _tint(metric.kind);

    return Semantics(
      label:
          '${metric.label} : ${metric.value} ${metric.target}, '
          '${metric.note}',
      button: onTap != null,
      container: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: _Tappable(
          onTap: onTap,
          child: ColoredBox(
            color: AppColors.darkSurface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gapRow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(_icon(metric.kind), size: 14, color: tint),
                      const SizedBox(width: AppSpacing.xs - 1),
                      Expanded(
                        child: Text(
                          metric.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.resized(
                                AppTypography.labelMono,
                                9,
                              ).copyWith(
                                letterSpacing: 1.4,
                                color: AppColors.textMuted,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gapTile - 1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        metric.value,
                        style: AppTypography.resized(AppTypography.metricM, 17)
                            .copyWith(
                              letterSpacing: -0.34,
                              color: AppColors.darkTextPrimary,
                            ),
                      ),
                      if (metric.target.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(
                            metric.target,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMono.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gapTile - 1),
                  TodayGauge(ratio: metric.ratio, tint: tint),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    metric.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(TodayMetricKind kind) => switch (kind) {
    TodayMetricKind.calories => AppIcons.nutrition,
    TodayMetricKind.proteines => AppIcons.protein,
    TodayMetricKind.hydratation => AppIcons.water,
    TodayMetricKind.volume => AppIcons.workout,
  };

  /// Le volume est le seul fait d'ENTRAÎNEMENT de la grille : il porte donc
  /// l'orange, les trois autres le violet de la nutrition.
  static Color _tint(TodayMetricKind kind) => kind == TodayMetricKind.volume
      ? AppColors.accent
      : AppColors.primaryLight;
}

/// Enrobage d'interaction posé UNIQUEMENT quand un geste existe : sans lui,
/// une cellule inerte capterait quand même les effets de pression, et
/// promettrait une action qui n'arriverait jamais.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}
