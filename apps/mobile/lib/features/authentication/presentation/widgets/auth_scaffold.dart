import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design_system/design_system.dart';
import 'auth_brand_header.dart';

/// Gabarit commun des écrans d'authentification, dans la disposition de la
/// maquette : décor en couche de fond, chevron de retour et signature de
/// marque FIGÉS en haut — au même niveau sur tous les écrans, quelle que
/// soit la longueur du contenu —, puis le reste (titre, formulaire) centré
/// verticalement dans l'espace restant, défilant s'il déborde.
///
/// Les écrans d'ENTRÉE (connexion, inscription) passent un [backdrop] et
/// `brand: true` — ce sont des surfaces de marque, sombres quel que soit le
/// réglage de thème, comme la page de bienvenue. Les écrans UTILITAIRES
/// (mot de passe oublié, changement, suppression) ne passent rien : même
/// squelette, fond au thème AMBIANT — atteints connecté, là où le réglage
/// clair s'applique, un fond sombre forcé sous des textes au thème rendrait
/// le titre illisible.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.backdrop,
    this.brand = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Décor pleine page derrière le contenu ([AuthBackdrop], typiquement).
  final Widget? backdrop;

  /// Surface de marque : signature compacte sous le chevron, et thème sombre
  /// IMPOSÉ à tout l'écran — champs, liens et titre compris.
  final bool brand;

  /// Le thème des surfaces de marque, construit une fois : celui que
  /// l'application applique en mode sombre — les captures validées.
  static final ThemeData _brandTheme = AppTheme.dark();

  @override
  Widget build(BuildContext context) {
    final theme = brand ? _brandTheme : Theme.of(context);

    final scaffold = Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (backdrop != null) Positioned.fill(child: backdrop!),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      // Le chevron dépile quand il y a quelque chose à
                      // dépiler, et disparaît sinon (AppBackButton) — mais
                      // sa PLACE reste réservée : la signature se pose au
                      // même niveau sur la connexion (sans retour) et
                      // l'inscription (avec).
                      SizedBox(
                        height: AppSpacing.touchTarget,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AppBackButton(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (brand) ...[
                        const SizedBox(height: AppSpacing.xs),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AuthBrandHeader(),
                        ),
                      ],
                      // Le reste se CENTRE dans l'espace sous la signature
                      // (demande produit : rien de collé en haut, mais la
                      // signature ne bouge pas d'un écran à l'autre) et
                      // redevient simplement défilant dès qu'il déborde —
                      // petits écrans, grande police, clavier ouvert.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, inner) => SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: inner.maxHeight - 2 * AppSpacing.md,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      title,
                                      style: theme.textTheme.headlineMedium,
                                    ),
                                    if (subtitle != null) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        subtitle!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // L'AppBar posait l'habillage de la barre de statut ; sans elle, on le
    // pose nous-mêmes, d'après la luminosité du thème EFFECTIF de l'écran.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: brand ? Theme(data: theme, child: scaffold) : scaffold,
    );
  }
}
