import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/metric_explanation.dart';

/// Ouvre le POURQUOI d'une donnée.
///
/// Trois blocs, toujours dans le même ordre : ce que c'est, d'où ça sort, et
/// ce que ça ne dit pas. Le troisième est facultatif mais c'est souvent le
/// plus utile — un IMC pris au pied de la lettre par un pratiquant de force,
/// une dépense estimée prise pour une mesure.
Future<void> showMetricExplanation(
  BuildContext context,
  MetricExplanation explication,
) {
  return showAppSheet<void>(
    context,
    style: AppSheetStyle.form,
    builder: (_) => _ExplanationBody(explication: explication),
  );
}

class _ExplanationBody extends StatelessWidget {
  const _ExplanationBody({required this.explication});

  final MetricExplanation explication;

  @override
  Widget build(BuildContext context) {
    final limites = explication.cequeCaNeDitPas;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(explication.titre, style: AppTypography.title),
          const SizedBox(height: AppSpacing.md),
          _Bloc(titre: 'Ce que c’est', corps: explication.cequeCest),
          const SizedBox(height: AppSpacing.md),
          _Bloc(titre: 'D’où ça sort', corps: explication.douCaSort),
          if (limites != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Bloc(titre: 'Ce que ça ne dit pas', corps: limites),
          ],
          const SizedBox(height: AppSpacing.gapSection),
          AppButton(
            label: 'J’ai compris',
            isExpanded: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  const _Bloc({required this.titre, required this.corps});

  final String titre;
  final String corps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(titre),
        const SizedBox(height: AppSpacing.xs),
        Text(
          corps,
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}
