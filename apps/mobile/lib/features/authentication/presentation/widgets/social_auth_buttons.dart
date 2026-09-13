import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/social_provider.dart';
import '../controllers/social_auth_controller.dart';
import 'google_glyph.dart';

/// Le séparateur « OU » et les entrées sociales : Apple et Google.
///
/// Le toucher ouvre la feuille du fournisseur, obtient un jeton d'identité et
/// le confie au SERVEUR, qui le vérifie et ouvre la session — la redirection
/// est ensuite l'affaire du routeur. Quand le fournisseur n'est pas encore
/// branché (serveur non configuré, client OAuth absent du build, Apple hors
/// iOS), on le DIT plutôt que d'afficher une panne ; renoncer devant la
/// feuille ne dit rien du tout.
class SocialAuthButtons extends ConsumerWidget {
  const SocialAuthButtons({this.enabled = true, super.key});

  /// Neutralisé pendant une soumission, comme le reste du formulaire.
  final bool enabled;

  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    SocialProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(socialAuthControllerProvider.notifier)
        .signIn(provider);

    final message = switch (outcome) {
      // Le routeur emmène ailleurs : rien à annoncer.
      SocialAuthSucceeded() => null,
      // Refermer la feuille n'est pas un échec.
      SocialAuthCancelled() => null,
      SocialAuthUnavailable() => outcome.message,
      SocialAuthFailed() => outcome.message,
    };
    if (message == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une tentative en cours neutralise les DEUX boutons : deux feuilles de
    // connexion ouvertes en même temps n'ont aucun sens.
    final enCours = ref.watch(socialAuthControllerProvider);
    final actif = enabled && enCours == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OrDivider(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (final provider in SocialProvider.values) ...[
              if (provider != SocialProvider.values.first)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SocialButton(
                  semanticLabel: 'Continuer avec ${provider.label}',
                  onPressed: actif
                      ? () => _signIn(context, ref, provider)
                      : null,
                  child: switch (provider) {
                    SocialProvider.apple => const Icon(
                      AppIcons.apple,
                      size: 26,
                      color: AppColors.neutral0,
                    ),
                    SocialProvider.google => const GoogleGlyph(size: 22),
                  },
                ),
              ),
            ],
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
