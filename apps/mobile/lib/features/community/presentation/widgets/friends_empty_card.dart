import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// La section « Amis » quand il n'y a encore personne : l'invitation à
/// ajouter un premier ami, à sa place, au milieu d'un écran qui n'est plus
/// vide.
///
/// Depuis que le serveur crée les défis du mois à la lecture, un compte
/// neuf voit toujours des défis : l'état vide global ne s'affiche plus, et
/// le geste qui débloque tout (ajouter un ami) doit survivre ici.
class FriendsEmptyCard extends StatelessWidget {
  const FriendsEmptyCard({required this.onAddFriend, super.key});

  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_outlined, color: AppColors.primaryLight),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Pas encore d’ami',
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ajoute un premier ami par son code ami ou son adresse e-mail : '
            'vous verrez vos séries, et vous pourrez vous encourager.',
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Ajouter un ami',
            icon: Icons.person_add_alt_1_outlined,
            size: AppButtonSize.small,
            onPressed: onAddFriend,
          ),
        ],
      ),
    );
  }
}
