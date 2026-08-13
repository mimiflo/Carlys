import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// En-tête de « Mes modèles » : retour, titre et création d'un modèle.
///
/// L'écran est en plein écran (hors coquille à onglets) : le retour est donc
/// explicite, comme sur la séance active.
class TemplatesHeader extends StatelessWidget {
  const TemplatesHeader({required this.onCreate, super.key});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // La flèche commune à toutes les pages poussées.
        const AppBackButton(),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            'Mes modèles',
            style: AppTypography.display.copyWith(
              fontSize: 27,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Créer un modèle de séance',
          child: GestureDetector(
            onTap: onCreate,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    AppIcons.add,
                    size: 17,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    'NOUVEAU',
                    style: AppTypography.labelMono.copyWith(
                      fontSize: 11,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
