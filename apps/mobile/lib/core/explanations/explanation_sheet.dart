import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import 'explanation.dart';

/// Ouvre le POURQUOI d'une donnée.
///
/// Trois blocs, toujours dans le même ordre : ce que c'est, d'où ça sort, et
/// ce que ça ne dit pas. Le troisième est facultatif mais c'est souvent le
/// plus utile — un IMC pris au pied de la lettre par un pratiquant de force,
/// une dépense estimée prise pour une mesure.
Future<void> showExplanation(BuildContext context, Explanation explication) {
  return showAppSheet<void>(
    context,
    style: AppSheetStyle.form,
    builder: (_) => _ExplanationBody(explication: explication),
  );
}

class _ExplanationBody extends StatelessWidget {
  const _ExplanationBody({required this.explication});

  final Explanation explication;

  @override
  Widget build(BuildContext context) {
    final limites = explication.cequeCaNeDitPas;

    // LA FEUILLE DÉFILE. Ses trois blocs sont du texte libre, et le dernier —
    // « ce que ça ne dit pas », souvent le plus utile — est le plus long. Une
    // simple colonne débordait dès qu'une explication s'allongeait, ou dès
    // que la taille de police du système montait : le bouton « J'ai compris »
    // passait sous le bord de l'écran et rien ne permettait d'aller le
    // chercher. La feuille se refermait alors au glissement, ou pas du tout.
    //
    // Le plafond laisse voir ce qu'il y a dessous : une feuille qui prend
    // tout l'écran n'a plus l'air d'une feuille.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
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
