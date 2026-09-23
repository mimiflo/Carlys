import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';

/// LE BARÈME, en trois tuiles et une ligne : ce qui rapporte des points.
///
/// Un score sans sa règle n'est qu'un chiffre. La maquette posait trois
/// tuiles ; le serveur compte AUSSI les bonnes réponses de l'Academy
/// (`docs/product/community.md`, barème complet), et l'ancienne carte les
/// taisait déjà. La quatrième règle vit donc sur une ligne sous les tuiles :
/// une tuile de plus ne tiendrait pas sur un téléphone, une règle de moins
/// ferait mentir le barème.
class LeagueRuleTiles extends StatelessWidget {
  const LeagueRuleTiles({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RuleTile(
                  icon: AppIcons.leagueSessionPoints,
                  color: AppColors.primary,
                  value: '50',
                  unit: 'pts la séance',
                  spoken: '50 points par séance terminée',
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _RuleTile(
                  icon: AppIcons.leagueEffortPoints,
                  color: AppColors.accent,
                  value: '1',
                  unit: 'pt la minute d’effort',
                  spoken: '1 point par minute d’effort',
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _RuleTile(
                  icon: AppIcons.leagueDistancePoints,
                  color: AppColors.primaryLight,
                  value: '1',
                  unit: 'pt les 100 m',
                  spoken: '1 point par centaine de mètres',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          container: true,
          child: Text(
            'Et 10 pts par bonne réponse du jour à l’Academy.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    required this.spoken,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String unit;
  final String spoken;

  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: const BoxDecoration(
          color: AppColors.darkBackground,
          borderRadius: AppRadius.mdAll,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.darkBorder),
          ),
        ),
        // L'icône À CÔTÉ du chiffre, le libellé dessous sur toute la largeur
        // de la tuile : posée à gauche de tout, elle lui volait une colonne,
        // et « pt la minute d’effort » tombait sur trois lignes.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: _iconSize, color: color),
                const SizedBox(width: AppSpacing.xxs),
                // Trois tuiles sur la largeur d'un téléphone : en grand texte,
                // le chiffre se réduit plutôt que de déborder de sa tuile.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: AppTypography.heading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              unit,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
