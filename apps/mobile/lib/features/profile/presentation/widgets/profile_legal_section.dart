import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/environment/app_environment.dart';
import '../../../../core/utilities/external_links.dart';
import '../../../../design_system/design_system.dart';

/// Groupe « LÉGAL » : la politique de confidentialité et les conditions
/// d'utilisation, à un geste des réglages.
///
/// Les deux textes vivent sur le WEB (`apps/admin`, groupe de routes
/// publiques) : ils changent sans livraison d'application, et une version
/// recopiée ici serait périmée le jour de sa première modification. Les
/// adresses viennent de la configuration d'exécution, jamais d'une chaîne en
/// dur : la même application pointe sur localhost en développement et sur le
/// domaine public en production.
///
/// Rien ne s'affiche si le navigateur ne s'ouvre pas : on le dit, plutôt que
/// de laisser croire à un appui sans effet.
class ProfileLegalSettings extends ConsumerWidget {
  const ProfileLegalSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);

    Future<void> open(Uri url) async {
      final messenger = ScaffoldMessenger.of(context);
      final opened = await ref.read(externalLinkOpenerProvider)(url);
      if (opened) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Aucun navigateur n’a pu ouvrir cette page.'),
        ),
      );
    }

    return AppSettingsGroup(
      label: 'Légal',
      rows: [
        AppSettingsRow(
          icon: AppIcons.privacy,
          label: 'Politique de confidentialité',
          onTap: () => open(environment.privacyPolicyUrl),
        ),
        AppSettingsRow(
          icon: AppIcons.terms,
          label: 'Conditions d’utilisation',
          onTap: () => open(environment.termsOfServiceUrl),
        ),
      ],
    );
  }
}
