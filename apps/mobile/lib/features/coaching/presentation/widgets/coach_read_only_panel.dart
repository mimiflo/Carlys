import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// À la place du composeur, quand le fil se RELIT sans plus s'écrire : le
/// coach est réservé aux abonnés, l'historique reste à qui l'a écrit.
///
/// Un composeur qui refuserait chaque question serait une porte peinte sur
/// un mur ; celui-ci dit pourquoi, et mène à l'abonnement.
class CoachReadOnlyPanel extends StatelessWidget {
  const CoachReadOnlyPanel({required this.onUnlock, super.key});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tes échanges restent à toi, à relire quand tu veux. Pour poser '
            'une nouvelle question, le coach demande Premium.',
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Voir Premium',
            icon: AppIcons.premium,
            isExpanded: true,
            onPressed: onUnlock,
          ),
        ],
      ),
    );
  }
}
