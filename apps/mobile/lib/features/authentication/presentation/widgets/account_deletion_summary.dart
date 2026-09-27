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
/// Trois précisions que le serveur impose au texte :
///  - le jour même, la suppression PSEUDONYMISE, elle ne détruit pas : la
///    ligne `User`, son identifiant et les clés étrangères survivent 30
///    jours. « Plus rien ne les relie à toi » serait donc une promesse que
///    personne ne tient ; « ton identité en est retirée » décrit ce qui se
///    passe.
///  - passé ce délai, `deleted-accounts-purge` (src/cli de l'API, lancé
///    chaque jour par la supervision) efface le compte et, par cascade, tout
///    ce qui s'y rattache. Le délai de 30 jours est celui de la politique
///    (section 6) et de `CARLYS_ACCOUNT_PURGE_DAYS` : changer l'un, c'est
///    changer tous les textes que SECURITY.md (« Données personnelles »)
///    énumère, celui-ci compris. Seul le journal d'audit survit, sans le
///    lien au compte et sans l'adresse (un échec de connexion n'y laisse
///    qu'une empreinte) ; sa durée porte encore un « à compléter » dans la
///    politique, et n'est donc pas écrite ici.
///  - l'effacement IMMÉDIAT (`deleted-accounts-purge --compte <uuid>`) ne
///    vise qu'un compte déjà supprimé, et la suppression efface tout ce qui
///    mène de la personne à cet identifiant : la demande doit donc précéder
///    la suppression (docs/deployment/orchestration.md, « Effacement
///    immédiat sur demande »), et l'écran le dit dans cet ordre.
///  - la suppression ne résilie pas un abonnement payé chez Stripe
///    (`AccountService.deleteAccount` n'y touche pas) : l'écran le dit, sans
///    quoi la personne découvre un prélèvement qu'elle ne peut plus arrêter
///    depuis l'application.
class AccountDeletionSummary extends ConsumerWidget {
  const AccountDeletionSummary({super.key});

  static const List<String> _erased = [
    'Ton adresse e-mail, ton nom et ton code ami. L’adresse redevient libre '
        'pour un nouveau compte.',
    'Ton profil personnel : date de naissance, sexe, taille.',
    'Toutes tes sessions, sur cet appareil comme sur les autres.',
    'Tes jetons de notification : plus rien ne t’est envoyé.',
    'Les photos de tes repas, et le lien avec ton compte Google ou Apple.',
  ];

  static const List<String> _kept = [
    'Ton historique d’entraînement, tes repas, tes mesures et tes échanges '
        'avec le coach restent en base 30 jours : ton identité en est '
        'retirée, mais les lignes ne sont pas détruites le jour même.',
    'Au bout de ces 30 jours, tout est effacé définitivement.',
    'Le journal de sécurité (connexions, actions sur ton compte) perd alors '
        'le lien avec ton compte, et ne garde jamais ton adresse e-mail ; il '
        'est gardé la durée qu’annonce la politique de confidentialité, puis '
        'supprimé.',
    'Pour tout effacer sans attendre ces 30 jours, écris-nous d’abord, '
        'depuis l’adresse de ton compte, à l’adresse de contact de cette même '
        'politique, puis supprime-le : une fois ton adresse effacée, plus rien '
        'ne nous permet de retrouver ton compte.',
    'Ton abonnement payant, si tu en as un : la suppression ne le résilie '
        'pas. Résilie-le d’abord avec « Gérer mon abonnement ».',
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
              notices: AppNotices.of(context),
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
