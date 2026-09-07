import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/environment/app_environment.dart';
import '../../../../core/utilities/external_links.dart';
import '../../../../design_system/design_system.dart';

/// Ce que la suppression du compte fait vraiment, dit avant de la demander.
///
/// Sur un geste irréversible, c'est la SEULE surface légale que l'utilisateur
/// lit : elle doit dire exactement ce que le serveur exécute
/// (`AccountService` + `UsersRepository.deleteAccount`) et exactement ce que
/// la politique annonce (`docs/legal/privacy.md`, section 6). Promettre un
/// effacement total serait faux, taire ce qui reste le serait aussi.
///
/// Deux précisions que le serveur impose au texte :
///  - la suppression PSEUDONYMISE, elle ne détruit pas : la ligne `User`, son
///    identifiant et les clés étrangères survivent, et le journal d'audit
///    garde `userId` ET l'adresse IP. « Plus rien ne les relie à toi » serait
///    donc une promesse que personne ne tient ; « ton identité en est
///    retirée » décrit ce qui se passe.
///  - le délai de purge et la durée de conservation des journaux ne sont PAS
///    écrits ici : ils portent encore un « à compléter » dans la politique.
///    Les inventer sur cet écran serait pire que d'y renvoyer, puisque c'est
///    la politique qui engage. Quand ces deux valeurs y seront posées, ce
///    texte pourra les nommer.
class AccountDeletionSummary extends ConsumerWidget {
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
        'restent en base : ton identité en est retirée, mais les lignes ne '
        'sont pas détruites le jour même.',
    'Elles sont conservées un temps, puis effacées ou rendues anonymes. Le '
        'délai est celui qu’annonce la politique de confidentialité.',
    'Le journal de sécurité (connexions, actions sur ton compte) est gardé '
        'la durée qu’elle annonce, puis supprimé.',
    'Tu peux demander un effacement immédiat : écris à l’adresse de contact '
        'indiquée dans cette même politique.',
    'Sur ce téléphone, rien : tout ce que Carlys garde en local est effacé '
        'au retour à l’écran de connexion.',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DeletionBlock(
          title: 'Effacé tout de suite',
          icon: AppIcons.deleteAccount,
          items: _erased,
        ),
        const SizedBox(height: AppSpacing.md),
        const _DeletionBlock(
          title: 'Ce qui reste',
          icon: AppIcons.info,
          items: _kept,
        ),
        // Le texte renvoie deux fois à la politique : elle doit être à un
        // geste d'ici, sinon « demande-le à l'adresse de contact » n'est pas
        // une instruction, c'est une formule.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => openExternalLink(
              environment.privacyPolicyUrl,
              ref: ref,
              messenger: ScaffoldMessenger.of(context),
            ),
            child: const Text('Lire la politique de confidentialité'),
          ),
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
