import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/environment/app_environment.dart';
import '../../../../core/utilities/external_links.dart';

/// La phrase de consentement, sous le bouton d'inscription.
///
/// Elle doit être LISIBLE AVANT le geste, et les deux textes doivent être
/// atteignables depuis là : une case à cocher qui renvoie à des documents
/// introuvables ne vaut rien. Les adresses viennent de la configuration
/// d'exécution, comme partout ailleurs.
///
/// Écrit en spans plutôt qu'en boutons : la phrase doit se lire d'un trait,
/// et deux boutons au milieu la casseraient en trois morceaux. Les
/// reconnaisseurs de geste sont libérés avec l'état, sinon ils fuient.
class LegalConsentNotice extends ConsumerStatefulWidget {
  const LegalConsentNotice({super.key});

  @override
  ConsumerState<LegalConsentNotice> createState() => _LegalConsentNoticeState();
}

class _LegalConsentNoticeState extends ConsumerState<LegalConsentNotice> {
  final _terms = TapGestureRecognizer();
  final _privacy = TapGestureRecognizer();

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _open(Uri url) =>
      openExternalLink(url, ref: ref, messenger: ScaffoldMessenger.of(context));

  @override
  Widget build(BuildContext context) {
    final environment = ref.watch(appEnvironmentProvider);
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall;
    final link = base?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    _terms.onTap = () => _open(environment.termsOfServiceUrl);
    _privacy.onTap = () => _open(environment.privacyPolicyUrl);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'En créant un compte, tu acceptes les '),
          TextSpan(
            text: 'conditions d’utilisation',
            style: link,
            recognizer: _terms,
          ),
          const TextSpan(text: ' et la '),
          TextSpan(
            text: 'politique de confidentialité',
            style: link,
            recognizer: _privacy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
