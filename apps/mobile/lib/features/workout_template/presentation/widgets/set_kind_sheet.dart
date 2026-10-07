import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../utils/template_draft.dart';
import 'planned_number_cell.dart';

/// Le nom d'un type de série dans l'éditeur : `SetKind.label` dit « Série »
/// pour la série normale, ce qui ne se lit pas comme un choix.
String setKindChoiceLabel(SetKind kind) => switch (kind) {
  SetKind.normal => 'Série normale',
  SetKind.warmup => 'Échauffement',
  SetKind.drop => 'Dégressive',
};

String _description(SetKind kind) => switch (kind) {
  SetKind.normal => 'La série de travail, à la charge prévue.',
  SetKind.warmup => 'Charge légère, pour préparer le mouvement.',
  SetKind.drop => 'Charge allégée, enchaînée sans repos.',
};

/// Choisir le type d'une série, ou de toutes celles d'un exercice. Rend le
/// type choisi, `null` si la feuille se ferme sans choix.
Future<SetKind?> showSetKindSheet(
  BuildContext context, {
  required String title,
  SetKind? current,
}) {
  return showAppSheet<SetKind>(
    context,
    style: AppSheetStyle.picker,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(title: title),
            const SizedBox(height: AppSpacing.sm),
            for (final kind in SetKind.values) ...[
              AppChoiceCard(
                title: setKindChoiceLabel(kind),
                description: _description(kind),
                selected: kind == current,
                selectedSemantics: 'Type actuel.',
                onTap: () => Navigator.of(sheetContext).pop(kind),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    ),
  );
}

/// « Type de série » : le même type pour toutes les séries de l'exercice.
/// Le rang de chaque ligne en change une seule.
class SetKindSelector extends StatelessWidget {
  const SetKindSelector({
    required this.sets,
    required this.onChoose,
    super.key,
  });

  final List<DraftSet> sets;
  final ValueChanged<SetKind> onChoose;

  Future<void> _choose(BuildContext context, SetKind? common) async {
    final kind = await showSetKindSheet(
      context,
      title: 'Type de toutes les séries',
      current: common,
    );
    if (kind != null) onChoose(kind);
  }

  @override
  Widget build(BuildContext context) {
    final kinds = {for (final set in sets) set.kind};
    final common = kinds.length == 1 ? kinds.single : null;
    final value = common == null
        ? 'Types mélangés'
        : setKindChoiceLabel(common);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            'Type de série',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          button: true,
          label: 'Type de série : $value. Changer pour toutes les séries',
          excludeSemantics: true,
          // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
          onTap: () => _choose(context, common),
          child: Material(
            color: AppColors.darkBackground,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.buttonAll,
              side: BorderSide(color: AppColors.darkBorder),
            ),
            child: InkWell(
              borderRadius: AppRadius.buttonAll,
              onTap: () => _choose(context, common),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: AppTypography.body.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                    const Icon(AppIcons.choose, color: AppColors.primaryLight),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Le rang de la série, qui dit aussi son type : l'échauffement en accent,
/// la dégressive en violet. Un toucher en change le type, pour elle seule.
class SetKindCell extends StatelessWidget {
  const SetKindCell({
    required this.position,
    required this.kind,
    required this.onTap,
    super.key,
  });

  final int position;
  final SetKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, color) = switch (kind) {
      SetKind.normal => (AppColors.darkBackground, AppColors.darkTextPrimary),
      SetKind.warmup => (AppColors.accentBadgeBg, AppColors.accent),
      SetKind.drop => (AppColors.primaryBadgeBg, AppColors.primaryLight),
    };
    final rank = formatThousands(position);
    return Semantics(
      button: true,
      label:
          'Série $rank, ${setKindChoiceLabel(kind).toLowerCase()}. '
          'Changer le type',
      excludeSemantics: true,
      // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
      onTap: onTap,
      child: Material(
        color: background,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.smAll,
          side: BorderSide(color: AppColors.darkBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smAll,
          child: SizedBox(
            height: PlannedNumberCell.height,
            child: Center(
              child: Text(
                rank,
                style: AppTypography.metricS.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
