import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'google_glyph.dart';

/// Le séparateur « OU » et les entrées sociales : Apple et Google.
///
/// LES FOURNISSEURS NE SONT PAS ENCORE BRANCHÉS — l'API n'expose que la
/// connexion par e-mail (Étape 2). Le toucher le dit franchement plutôt que
/// d'échouer en silence ou de simuler : un message nomme le fournisseur et
/// renvoie vers l'e-mail. Le jour où l'API saura, seul `_announce` change.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({this.enabled = true, super.key});

  /// Neutralisé pendant une soumission, comme le reste du formulaire.
  final bool enabled;

  void _announce(BuildContext context, String provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'La connexion avec $provider arrive bientôt. Utilise ton '
            'adresse e-mail en attendant.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OrDivider(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                semanticLabel: 'Continuer avec Apple',
                onPressed: enabled ? () => _announce(context, 'Apple') : null,
                child: const Icon(
                  AppIcons.apple,
                  size: 26,
                  color: AppColors.neutral0,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SocialButton(
                semanticLabel: 'Continuer avec Google',
                onPressed: enabled ? () => _announce(context, 'Google') : null,
                child: const GoogleGlyph(size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Trait — OU — trait, comme la maquette.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: AppColors.darkBorderStrong, height: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'OU',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.darkTextTertiary,
              letterSpacing: 2,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Pastille sombre à bord discret, hauteur de bouton du système.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;
  final Widget child;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonAll,
            side: const BorderSide(color: AppColors.darkBorder),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: SizedBox(
              height: _height,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
