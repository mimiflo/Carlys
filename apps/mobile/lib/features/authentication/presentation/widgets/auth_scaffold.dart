import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'auth_brand_header.dart';

/// Gabarit commun des écrans d'authentification, dans la disposition de la
/// maquette : décor en couche de fond, chevron de retour flottant, signature
/// de marque compacte, titre porté haut, contenu en colonne bornée.
///
/// Les écrans d'ENTRÉE (connexion, inscription) passent un [backdrop] et
/// `brand: true` — ce sont des surfaces de marque. Les écrans UTILITAIRES
/// (mot de passe oublié, changement, suppression) ne passent rien : même
/// squelette, fond sobre.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.backdrop,
    this.brand = false,
    this.heroSpaceFactor = 0,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Décor pleine page derrière le contenu ([AuthBackdrop], typiquement).
  final Widget? backdrop;

  /// Affiche la signature de marque compacte sous le chevron de retour.
  final bool brand;

  /// Part de la hauteur d'écran laissée au décor entre la signature et le
  /// titre — c'est là que la photographie ou le cœur respirent. Zéro pour
  /// les écrans sobres.
  final double heroSpaceFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          if (backdrop != null) Positioned.fill(child: backdrop!),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Le chevron dépile quand il y a quelque chose à
                        // dépiler, et disparaît sinon (AppBackButton) — la
                        // connexion, premier écran, n'affiche rien.
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AppBackButton(),
                        ),
                        if (brand) ...[
                          const SizedBox(height: AppSpacing.xs),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: AuthBrandHeader(),
                          ),
                        ],
                        if (heroSpaceFactor > 0)
                          SizedBox(
                            height: constraints.maxHeight * heroSpaceFactor,
                          )
                        else
                          const SizedBox(height: AppSpacing.lg),
                        Text(title, style: theme.textTheme.headlineMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
