import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/dashboard_controllers.dart';
import 'section_title_bar.dart';

/// LA FORME DU JOUR : une échelle graduée, pas un score.
///
/// Un « 40 » en chiffres de 62 points ne disait rien : ni sur quoi il porte,
/// ni s'il est bon. L'échelle le remplace par une position entre trois
/// bandes nommées — repos, charge juste, surcharge — et par la phrase qui
/// explique d'où elle vient.
///
/// Ce n'est PAS une mesure de santé : c'est la part de l'objectif
/// hebdomadaire déjà faite. La copie ne promet donc jamais autre chose que
/// ce que l'application sait vraiment.
class DailyFormBlock extends StatelessWidget {
  const DailyFormBlock({
    required this.reading,
    required this.sessions,
    super.key,
  });

  /// `null` tant que la semaine n'est pas lue.
  final FormReading? reading;

  /// Séances terminées cette semaine.
  final int? sessions;

  @override
  Widget build(BuildContext context) {
    final form = reading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitleBar(
          icon: AppIcons.form,
          label: 'Forme du jour',
          trailing: form == null ? null : '${form.score} / 100',
        ),
        if (form != null) ...[
          const SizedBox(height: AppSpacing.padCard),
          Text(
            form.headline,
            style: AppTypography.title.copyWith(
              fontSize: 20,
              letterSpacing: -0.6,
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            form.explanation,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.padCard),
          FormScale(score: form.score),
          const SizedBox(height: AppSpacing.gapTile),
          _BandLabels(band: form.band),
        ],
        const SizedBox(height: AppSpacing.lg - AppSpacing.xxs),
        const Divider(height: 1, color: AppColors.gridRule),
        const SizedBox(height: AppSpacing.md),
        _SessionsFooter(sessions: sessions),
      ],
    );
  }
}

/// L'ÉCHELLE : vingt crans, dont un seul est allumé.
///
/// Vingt plutôt que cent : un cran vaut cinq points, ce qui se compte du
/// regard. Le cran courant est plus haut que les autres — c'est lui qu'on
/// cherche, pas la longueur de ce qui précède.
@visibleForTesting
class FormScale extends StatelessWidget {
  const FormScale({required this.score, super.key});

  final int score;

  static const int notches = 20;
  static const double boxHeight = 14;
  static const double _restHeight = 9;
  static const double _gap = 3;

  /// Le cran où tombe un score, de 1 à [notches].
  static int notchOf(int score) =>
      (score / 100 * notches).round().clamp(1, notches);

  @override
  Widget build(BuildContext context) {
    final current = notchOf(score);

    return SizedBox(
      height: boxHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 1; index <= notches; index++) ...[
            if (index > 1) const SizedBox(width: _gap),
            Expanded(
              child: Container(
                height: index == current ? boxHeight : _restHeight,
                decoration: BoxDecoration(
                  color: index == current
                      ? AppColors.accent
                      : index < current
                      ? AppColors.accentSoft
                      : AppColors.pendingBar,
                  borderRadius: AppRadius.fullAll,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Les trois bandes. Celle où l'on se trouve s'allume, les deux autres
/// restent lisibles : on doit voir vers quoi on penche.
class _BandLabels extends StatelessWidget {
  const _BandLabels({required this.band});

  final FormBand band;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, value) in FormBand.values.indexed)
          Expanded(
            child: Text(
              value.label.toUpperCase(),
              textAlign: switch (index) {
                0 => TextAlign.left,
                1 => TextAlign.center,
                _ => TextAlign.right,
              },
              style: AppTypography.labelMono.copyWith(
                fontSize: 9,
                fontWeight: value == band ? FontWeight.w700 : FontWeight.w500,
                color: value == band ? AppColors.accent : AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// Le compte de séances : le fait brut d'où sort tout le reste du bloc.
class _SessionsFooter extends StatelessWidget {
  const _SessionsFooter({required this.sessions});

  final int? sessions;

  static const double _dashWidth = 16;
  static const double _dashHeight = 4;

  @override
  Widget build(BuildContext context) {
    final done = sessions ?? 0;

    return Semantics(
      label:
          '$done séance${done > 1 ? 's' : ''} '
          'sur $weeklySessionsTarget cette semaine',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              sessions == null ? '—' : '$done',
              style: AppTypography.metricM.copyWith(
                fontSize: 17,
                letterSpacing: -0.34,
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'séances / $weeklySessionsTarget cette semaine',
                style: AppTypography.label.copyWith(
                  fontSize: 12,
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ),
            for (var index = 0; index < weeklySessionsTarget; index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.xxs),
              Container(
                width: _dashWidth,
                height: _dashHeight,
                decoration: BoxDecoration(
                  color: index < done
                      ? AppColors.primaryLight
                      : AppColors.pendingBar,
                  borderRadius: AppRadius.fullAll,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
