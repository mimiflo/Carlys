import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_back_button.dart';

/// L'en-tête des écrans de la refonte : un titre, une ligne mono en
/// capitales, et des actions rondes à droite.
///
/// Né dans le profil (« Mon profil / TON PARCOURS, TA PROGRESSION. »), repris
/// par la Communauté (« Communauté / ENSEMBLE, PLUS LOIN ») : deux copies
/// d'un en-tête finissent toujours par différer d'un point, et c'est le
/// premier écart qu'un œil remarque en passant d'un écran à l'autre.
///
/// Le retour vit AU-DESSUS du titre plutôt qu'à sa gauche : la ligne mono est
/// longue et ne tiendrait pas entre deux boutons. Un écran d'onglet n'en a
/// pas ([showBack] faux) ; sur un écran poussé, il disparaît de lui-même
/// quand il n'y a rien à dépiler.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    required this.title,
    required this.tagline,
    this.actions = const [],
    this.showBack = true,
    super.key,
  });

  final String title;

  /// Écrite en capitales à l'affichage.
  final String tagline;

  /// Des `AppRoundIconButton`, en général.
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBack) ...[
          const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTypography.pageTitle.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tagline.toUpperCase(),
                    style: AppTypography.resized(
                      AppTypography.labelMono,
                      11,
                    ).copyWith(color: AppColors.darkTextSecondary),
                  ),
                ],
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: AppSpacing.sm),
              action,
            ],
          ],
        ),
      ],
    );
  }
}
