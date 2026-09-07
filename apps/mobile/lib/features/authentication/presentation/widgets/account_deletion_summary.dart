import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Ce que la suppression du compte fait vraiment, dit avant de la demander.
///
/// Le texte suit à la lettre ce que le serveur exécute (`AccountService`) et
/// ce que la politique de confidentialité annonce (`docs/legal/privacy.md`,
/// sections « Combien de temps » et « Tes droits ») : promettre un effacement
/// total serait faux, taire ce qui reste le serait aussi.
class AccountDeletionSummary extends StatelessWidget {
  const AccountDeletionSummary({super.key});

  static const List<String> _erased = [
    'Ton adresse e-mail, ton nom et ton code ami. L’adresse redevient libre '
        'pour un nouveau compte.',
    'Ton profil personnel : date de naissance, sexe, taille.',
    'Toutes tes sessions, sur cet appareil comme sur les autres.',
    'Tes jetons de notification : plus rien ne t’est envoyé.',
  ];

  static const List<String> _kept = [
    'Ton historique d’entraînement, tes repas et tes échanges avec le coach '
        'restent en base, mais plus rien ne les relie à toi.',
    'Le journal de sécurité, gardé le temps annoncé par la politique de '
        'confidentialité.',
    'Sur ce téléphone, rien : tout ce que Carlys garde en local est effacé '
        'au retour à l’écran de connexion.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _DeletionBlock(
          title: 'Effacé tout de suite',
          icon: AppIcons.deleteAccount,
          items: _erased,
        ),
        SizedBox(height: AppSpacing.md),
        _DeletionBlock(
          title: 'Ce qui reste',
          icon: AppIcons.info,
          items: _kept,
        ),
      ],
    );
  }
}

class _DeletionBlock extends StatelessWidget {
  const _DeletionBlock({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text('• $item', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
